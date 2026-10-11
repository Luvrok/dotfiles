#!/usr/bin/env bash
# Запуск генерации из агента (pi и т.п.): принять промпт, записать его слотом в файл промптов,
# стартовать qwen-batch в фоне и сразу выйти. Агент результата не ждёт.
#
#   qwen-gen.sh --prompt 'текст' [--neg 'текст'] [--size 1248x832] [--cfg 2.5] [--steps 40]
#               [--seed "111 222"] [--variants 3] [--ref картинка [--reframe]]
#   DRY=1 qwen-gen.sh --prompt ...   # проверка: записать слот и показать команду sd-cli, без фона и выгрузки
#
# cfg и шаги без флага берутся из дефолтов qwen-batch. cfg принимается от 1.0 до 6.0.
# Референс: --ref путь, или --ref REF=путь, или REF=путь перед командой. С референсом --size не нужен
# (кадр по пропорциям референса); другой формат — только вместе с --reframe.
# Защита от ошибок модели: промпт ссылается на картинку, а --ref нет → отказ; --ref есть, а промпт
# описывает сцену с нуля (нет слов the image) → отказ; --ref вместе с --size без --reframe → отказ.
#
# В слот пишется всё, из чего сделана картинка: P N S C T D R (промпт, негатив, размер, cfg, шаги, сиды,
# референс). Номер слота выдаётся сам: следующий после самого большого P[n]. Сид не задан → случайный.
# Слот остаётся в файле, его можно повторить или перегнать с другими параметрами руками:
#   qwen-batch 40
#   CFG=3 SEEDS="303" qwen-batch 40
#
# Фоновый процесс после выхода:
#   1. ждёт своей очереди — одна генерация за раз;
#   2. ждёт, пока LLM в llama-swap договорит ответ (смотрит /slots у llama-server);
#   3. выгружает модели llama-swap: sd-cli идёт мимо llama-swap, сам он VRAM не освободит;
#   4. запускает qwen-batch <слот>. Всё пишется в run.log в папке картинок, в конце notify-send, если он есть.
set -uo pipefail

# ═══════════════════════════ НАСТРОЙКИ (всё можно задать переменной окружения) ═══════════════════════════

BATCH=${QWEN_BATCH:-$HOME/.local/bin/qwen-batch}   # основной скрипт
SWAP=${LLAMA_SWAP_URL:-http://127.0.0.1:11434}     # адрес llama-swap; ключ, если есть: LLAMA_SWAP_API_KEY
# Папка картинок, файл промптов, cfg и шаги по умолчанию спрашиваются у qwen-batch (--defaults), чтобы не
# держать их в двух местах. Переопределить только для лаунчера: QWEN_OUT, QWEN_PROMPTS, QWEN_CFG, QWEN_STEPS.
PROMPTS=${QWEN_PROMPTS:-}                          # пусто → путь из qwen-batch --defaults; в фоне приходит от запускавшего

GRACE=${QWEN_GRACE:-3}           # сек: пауза перед первой проверкой, чтобы агент успел получить ответ и начать писать
IDLE_NEED=${QWEN_IDLE:-4}        # сек подряд без генерации → считаем, что LLM закончила
IDLE_MAX=${QWEN_IDLE_MAX:-900}   # сек: дольше не ждём, запускаем как есть
DELAY=${QWEN_DELAY:-20}          # сек: простая пауза, если занятость LLM узнать нельзя (нет curl, нет /slots)

SELF=$(readlink -f -- "${BASH_SOURCE[0]}")

# qwen-batch запускается только с номером слота: всё остальное он берёт из слота.
# Одноимённые переменные из окружения агента убираются, иначе они перекрыли бы слот.
run_batch() { env -u SIZE -u CFG -u STEPS -u SEEDS -u REF PROMPTS="$PROMPTS" OUT="$OUT" "$@"; }

# ═══════════════════════════ ФОНОВАЯ ЧАСТЬ ═══════════════════════════

wlog() { printf '%s  [слот %s] %s\n' "$(date '+%F %T')" "${QG_SLOT:-?}" "$*" >>"$LOG"; }

# api МЕТОД ПУТЬ [ТАЙМАУТ] → тело ответа; код возврата ≠ 0, если ответ не 2xx или сервер недоступен
api() {
  local a=(-fsS -m "${3:-5}" -X "$1")
  [[ -n ${LLAMA_SWAP_API_KEY:-} ]] && a+=(-H "Authorization: Bearer $LLAMA_SWAP_API_KEY")
  curl "${a[@]}" "$SWAP$2" 2>/dev/null
}

# состояние моделей в llama-swap:
#   down — не отвечает | none — ничего не загружено | busy — идёт генерация или модель грузится
#   idle — загружено и молчит | blind — загружено, но /slots не отдаёт (занятость неизвестна)
llm_state() {
  local run obj m st body seen=0
  run=$(api GET /running) || { echo down; return; }
  local objs=()
  mapfile -t objs < <(grep -oE '\{[^{}]*"model"[^{}]*\}' <<<"$run")
  local loaded=0
  for obj in "${objs[@]}"; do
    m=$(sed -nE 's/.*"model"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' <<<"$obj")
    st=$(sed -nE 's/.*"state"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' <<<"$obj")
    [[ -z $m || $st == stopped || $st == shutdown ]] && continue
    loaded=1
    [[ -n $st && $st != ready ]] && { echo busy; return; } # starting / stopping
    body=$(api GET "/upstream/$m/slots") || continue        # sd-server и т.п.: слотов нет
    grep -q '"is_processing"' <<<"$body" || continue
    seen=1
    grep -qE '"is_processing"[[:space:]]*:[[:space:]]*true' <<<"$body" && { echo busy; return; }
  done
  if ((!loaded)); then echo none; elif ((seen)); then echo idle; else echo blind; fi
}

unload_models() {
  if ! api POST /api/models/unload 60 >/dev/null && ! api GET /unload 60 >/dev/null; then
    wlog "llama-swap не выгрузил модели — запускаю как есть"
    return
  fi
  local run
  for _ in {1..30}; do # ждём, пока процессы реально завершатся и отдадут VRAM
    run=$(api GET /running) || break
    grep -qE '"state"[[:space:]]*:[[:space:]]*"(ready|starting|stopping)"' <<<"$run" || break
    sleep 1
  done
  sleep 1
  wlog "модели llama-swap выгружены"
}

free_vram() {
  if ! command -v curl >/dev/null; then
    wlog "нет curl — жду ${DELAY}с и запускаю, модели не выгружены"
    sleep "$DELAY"
    return
  fi
  sleep "$GRACE"
  local idle=0 waited=0 st
  while ((idle < IDLE_NEED && waited < IDLE_MAX)); do
    st=$(llm_state)
    case $st in
      none) return ;;
      down)
        wlog "llama-swap не отвечает по $SWAP (см. LLAMA_SWAP_URL) — жду ${DELAY}с и запускаю, модели не выгружены"
        sleep "$DELAY"
        return
        ;;
      blind)
        wlog "llama-server не отдаёт /slots, занятость LLM неизвестна — жду ${DELAY}с и выгружаю"
        sleep "$DELAY"
        break
        ;;
      busy) idle=0 ;;
      idle) idle=$((idle + 1)) ;;
    esac
    sleep 1
    waited=$((waited + 1))
  done
  ((waited >= IDLE_MAX)) && wlog "LLM занята дольше ${IDLE_MAX}с — выгружаю не дожидаясь"
  unload_models
}

worker() {
  OUT=$QWEN_OUT LOG=$QWEN_OUT/run.log   # папку передал запускавший процесс
  mkdir -p "$OUT"
  if command -v flock >/dev/null; then
    exec 9>"$OUT/.qwen-gen.lock"
    flock 9
  fi
  wlog "в очереди первый, жду освобождения VRAM"
  free_vram

  # stdout qwen-batch уже дублирует в run.log сам; stderr (сообщения die) туда не попадает — дописываем
  run_batch env -u DRY bash "$BATCH" "$QG_SLOT" >/dev/null 2>>"$LOG" 9>&-
  local rc=$?

  if command -v notify-send >/dev/null; then
    if ((rc == 0)); then
      notify-send "qwen: слот $QG_SLOT готов" "$OUT" 2>/dev/null
    else
      notify-send -u critical "qwen: слот $QG_SLOT — ошибка" "$LOG" 2>/dev/null
    fi
  fi
  return "$rc"
}

if [[ ${1:-} == --worker ]]; then
  worker
  exit
fi

# ═══════════════════════════ ЗАПУСК ═══════════════════════════
# Сообщения ниже читает модель, поэтому они на английском.

die() { printf 'error: %s\n' "$*" >&2; exit 2; }
setup() { die "setup problem: $*. This cannot be fixed by changing the command: tell the user and stop."; }
clean() { printf '%s' "$1" | tr '\n\r\t' '   ' | sed -E 's/  +/ /g; s/^ //; s/ $//'; }
quote() { printf "'%s'" "${1//\'/\'\\\'\'}"; } # строка в одинарных кавычках для bash
int_in() { [[ $1 =~ ^[0-9]+$ ]] && ((10#$1 >= $2 && 10#$1 <= $3)); }
rand_seed() {
  local r
  r=$(od -An -N4 -tu4 /dev/urandom 2>/dev/null | tr -d ' ')
  [[ $r =~ ^[0-9]+$ ]] || r=$(((RANDOM << 15) | RANDOM))
  echo $((r % 999999999 + 1))
}

prompt='' neg='' size='' cfg='' steps='' seed_in='' variants='' ref='' reframe=''
while (($#)); do
  case $1 in --?*=*) set -- "${1%%=*}" "${1#*=}" "${@:2}" ;; esac # --size=1x1 → --size 1x1
  case $1 in
    --prompt | --neg | --negative | --size | --cfg | --steps | --seed | --seeds | --variants | --ref)
      (($# >= 2)) || die "option $1 needs a value"
      case $1 in
        --prompt) prompt=$2 ;;
        --neg | --negative) neg=$2 ;;
        --size) size=$2 ;;
        --cfg) cfg=$2 ;;
        --steps) steps=$2 ;;
        --seed | --seeds) seed_in=$2 ;;
        --variants) variants=$2 ;;
        --ref) ref=$2 ;;
      esac
      shift 2
      ;;
    --reframe)
      reframe=1
      shift
      ;;
    -h | --help)
      sed -n '2,13p' "$SELF"
      exit 0
      ;;
    -*) die "unknown option $1. Options: --prompt --neg --size --cfg --steps --seed --variants --ref --reframe" ;;
    *)
      [[ -z $prompt ]] || die "unexpected argument. The whole prompt goes into one single-quoted --prompt value"
      prompt=$1
      shift
      ;;
  esac
done

# дефолты, папка картинок и файл промптов — из qwen-batch
[[ -f $BATCH ]] || setup "$BATCH not found (QWEN_BATCH)"
defs=$(bash "$BATCH" --defaults 2>/dev/null) && [[ $defs == *OUT=* && $defs == *PROMPTS=* ]] ||
  setup "$BATCH does not answer --defaults with OUT and PROMPTS: it is an older version than this launcher"
def() { sed -n "s/^$1=//p" <<<"$defs" | head -1; }
OUT=${QWEN_OUT:-$(def OUT)}
PROMPTS=${PROMPTS:-$(def PROMPTS)}
LOG=$OUT/run.log
[[ -n $OUT && -n $PROMPTS ]] || setup "$BATCH --defaults gave an empty OUT or PROMPTS"

prompt=$(clean "$prompt")
neg=$(clean "$neg")
bad='[][()<>]'
[[ -n $prompt ]] || die "--prompt is empty"
[[ $prompt =~ $bad ]] && die "the prompt contains one of ( ) [ ] < >. Remove these characters and run the command again"
[[ $neg =~ $bad ]] && die "the negative prompt contains one of ( ) [ ] < >. Remove these characters and run the command again"

# референс: --ref путь | --ref REF=путь | REF=путь перед командой
ref=${ref:-${REF:-}}
ref=${ref#REF=}
low=" ${prompt,,} "
if [[ -z $ref ]]; then
  # промпт ссылается на картинку, которой модель не получит
  points='[^a-z](references?|the original|(source|input|given|attached|provided|uploaded) (image|picture|photo|file)|from the (image|picture|photo))[^a-z]'
  if [[ $low =~ $points ]]; then
    die "the prompt points at an existing picture with the words \"${BASH_REMATCH[1]}\", but --ref is missing, so the image model would get no picture. If the user gave an image file, add --ref with its path and rewrite the prompt as a short instruction about the image. You do not need to see the file. If there is no image file, remove these words: without --ref the prompt must describe the whole picture by itself"
  fi
else
  [[ $low == *"the image"* ]] ||
    die "with --ref the prompt must be a short instruction about the reference and must call it the image, like: Turn the image into a realistic photograph. Keep the composition and every figure exactly as they are in the image. Do not describe the scene from scratch: the image model reads the file itself"
  [[ -n $size && -z $reframe ]] &&
    die "--size together with --ref: remove --size, the picture takes the proportions of the reference. Only if the user asked for a different format or a wider frame, keep --size and add --reframe"
fi

if [[ -n $size ]]; then
  size=${size,,}
  [[ $size =~ ^([0-9]+)x([0-9]+)$ ]] || die "--size must look like 1248x832"
  ((BASH_REMATCH[1] > 0 && BASH_REMATCH[2] > 0 && BASH_REMATCH[1] % 32 == 0 && BASH_REMATCH[2] % 32 == 0)) ||
    die "--size $size: both sides must be multiples of 32. Use one of 1248x832 832x1248 1152x864 864x1152 1536x864 864x1536 1024x1024"
fi
cfg=${cfg:-${QWEN_CFG:-$(def CFG)}}
steps=${steps:-${QWEN_STEPS:-$(def STEPS)}}
[[ $cfg =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--cfg must be a number like 2.5"
awk -v c="$cfg" 'BEGIN { exit !(c >= 1 && c <= 6) }' ||
  die "--cfg $cfg is out of range: use 1.0 to 6.0. The usual values are 2 to 3 for photos and 3 to 4 for illustrations"
int_in "$steps" 1 200 || die "--steps must be an integer from 1 to 200"
[[ -z $variants ]] || int_in "$variants" 1 16 || die "--variants must be an integer from 1 to 16"

notes=()
if [[ -n $neg ]] && awk -v c="$cfg" 'BEGIN { exit !(c == 1) }'; then
  notes+=("at cfg 1.0 the negative prompt has no effect; it is saved with the slot but not used")
fi
if [[ $size =~ ^([0-9]+)x([0-9]+)$ ]] && ((BASH_REMATCH[1] * BASH_REMATCH[2] > 1700000)); then
  notes+=("size $size is far above 1 megapixel: it takes several times longer and this engine adds a visible grid pattern there")
fi

seeds=()
read -ra seeds <<<"${seed_in//,/ }"
for s in "${seeds[@]}"; do [[ $s =~ ^[0-9]+$ ]] || die "--seed must be a number, or several numbers separated by spaces"; done
while ((${#seeds[@]} < ${variants:-1})); do seeds+=("$(rand_seed)"); done

if [[ -n $ref ]]; then
  # модель передаёт путь в одинарных кавычках, тильду оболочка не раскроет
  # shellcheck disable=SC2088
  [[ $ref == "~/"* ]] && ref=$HOME/${ref#"~/"}
  [[ -f $ref ]] || die "reference image not found: $ref. Use the exact path the user gave; if it does not exist, ask the user"
  ref=$(readlink -f -- "$ref")
fi

command -v "${SD:-sd-cli}" >/dev/null || setup "${SD:-sd-cli} is not in PATH"
mkdir -p "$OUT" "$(dirname -- "$PROMPTS")" 2>/dev/null || setup "cannot create $OUT"
[[ -w $OUT ]] || setup "$OUT is not writable (QWEN_OUT)"

# слот: номер и запись в файл под блокировкой, чтобы два запуска подряд не взяли один номер
exec 8>>"$PROMPTS" || setup "cannot write $PROMPTS (QWEN_PROMPTS)"
command -v flock >/dev/null && flock 8
last=$(grep -ohE '^[[:space:]]*P\[[0-9]+\]=' "$BATCH" "$PROMPTS" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)
slot=$((10#${last:-0} + 1))
{
  if [[ ! -s $PROMPTS ]]; then
    printf '# Слоты для qwen-batch. Сюда дописывает qwen-gen.sh, править руками можно.\n'
    printf '# P промпт | N негатив | S размер | C cfg | T шаги | D сиды | R референс. Обязателен только P.\n'
  fi
  printf '\n# ── %d ── %s\n' "$slot" "$(date '+%F %H:%M')"
  printf 'P[%d]=%s\n' "$slot" "$(quote "$prompt")"
  printf 'N[%d]=%s\n' "$slot" "$(quote "$neg")"
  [[ -n $size ]] && printf 'S[%d]=%s\n' "$slot" "$size"
  printf 'C[%d]=%s\n' "$slot" "$cfg"
  printf 'T[%d]=%s\n' "$slot" "$steps"
  printf 'D[%d]=%s\n' "$slot" "$(quote "${seeds[*]}")"
  [[ -n $ref ]] && printf 'R[%d]=%s\n' "$slot" "$(quote "$ref")"
} >&8
exec 8>&-
bash -n "$PROMPTS" || setup "$PROMPTS has a syntax error after writing slot $slot"

if [[ -n ${DRY:-} ]]; then
  run_batch env DRY=1 bash "$BATCH" "$slot"
  exit
fi

export QG_SLOT=$slot QWEN_BATCH=$BATCH QWEN_PROMPTS=$PROMPTS QWEN_OUT=$OUT LLAMA_SWAP_URL=$SWAP
if command -v setsid >/dev/null; then
  setsid -f bash "$SELF" --worker </dev/null >/dev/null 2>&1
else
  nohup bash "$SELF" --worker </dev/null >/dev/null 2>&1 &
fi

size_note=${size:-$(def SIZE)}
[[ -z $size && -n $ref ]] && size_note='from the reference'
printf 'started: slot %d | size %s | cfg %s | steps %s | seeds %s%s\n' "$slot" \
  "$size_note" "$cfg" "$steps" "${seeds[*]}" "${ref:+ | reference ${ref##*/}}"
((${#notes[@]})) && printf 'note: %s\n' "${notes[@]}"
[[ -n $ref ]] && printf 'The image model reads the reference file itself. Do not tell the user that you cannot see the picture.\n'
printf 'images will appear in %s\n' "$OUT"
printf 'The image is rendered in the background and only after this model is unloaded from VRAM, which takes minutes. Do not wait, do not check files or logs, run no other command. Give your short reply and end your turn.\n'
