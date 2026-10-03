---
name: qwen-image-prompts
description: Write prompts, negative prompts, sizes and launch parameters for the Qwen-Image-2.1 image model run through qwen-batch.sh, with or without a reference image. Use when the user asks for image generation prompts, image edits from a reference, or a batch of pictures on a theme.
---

# Prompts for Qwen-Image-2.1 (qwen-batch.sh)

The user gives an idea for a picture, in any language. Reply in chat with a block to paste into `qwen-batch.sh` plus a launch line. Do not ask clarifying questions, and do not read files, run commands, or edit the script unless the user asks.

## Your creative room

Only what the user states is fixed: named objects, counts, colors, positions, exact text. Carry those over unchanged. Everything else is yours to invent, and you are expected to: the setting, the moment, the angle, the weather, the light, small telling details, the mood. Prefer a specific, surprising picture over a safe generic one. When asked for several prompts on a theme, make them clearly different pictures, not one scene reworded.

## Writing the prompt

The model responds best to one English paragraph that describes the finished image as an observer would, not to commands or tag lists. Whatever you leave undescribed, the model fills in on its own.

- Open by naming the kind of image, its style, the subject, and the setting or palette: `A wide realistic photograph of …`, `A vertical flat-vector poster of …`.
- Then place things. Say where each important element sits (on the left, in the foreground, in the upper-right corner, behind the subject) so the composition is not left to chance.
- Describe through what is visible: materials, colors with a modifier (deep navy, pale cream), each garment, posture, expression. Enumerate instead of writing "various items".
- Give the light a sentence: where it comes from, how hard or soft it is, what shadows and highlights it leaves.
- Close with one sentence on the overall composition and mood.
- Text that must appear in the image goes in straight double quotes, with where it sits and what it looks like: `a bold white headline across the top reads "…"`. Keep it in its own script.
- Present tense, declarative. No `create`, `make`, `should`. No quality boosters like `masterpiece` or `8K`. No sizes or aspect ratios in the text.
- Length follows the scene: roughly 150 to 450 words. A single object can be short; a dense scene with text needs more.

## Hard limits (sd.cpp and bash)

- Prompt and negative prompt are each one line.
- Never use the apostrophe `'`: write `the hat of the man`, `do not`.
- Never use `( ) [ ] < >`.
- Double quotes only around text that is written in the image.

## Negative prompt

Optional, and it only works when CFG is above 1. A short comma-separated list of what could wrongly appear in this image: the opposite style, typical defects, unwanted processing. Leave `N[n]=''` when there is nothing specific to exclude.

## With a reference image

The script takes one reference image for the whole run through `REF=path`. Every prompt in that run is then an instruction about that image, not a description from scratch. Refer to it as `the image`.

- **Changing the picture.** Lead with the operation and say exactly what changes, concretely and strongly enough that the result cannot be mistaken for the original. Then one blanket clause that everything else stays as in the image. Do not describe the parts that stay: describing them makes the model redraw them. Example: `Replace the overcast sky in the image with a clear deep-blue evening sky with a thin crescent moon. Keep the buildings, the street, the people and the framing exactly as they are in the image.`
- **A new picture of the same subject.** Point at the subject (`the woman from the image`, `the product from the image`) instead of describing its features, and build the new scene around it with the full freedom described above: setting, light, composition.
- State things affirmatively and decisively. Add nothing the user did not ask for.
- Size: leave `S[n]` out and the script keeps the proportions of the reference. Set `S[n]` only when the new picture should have a different format.
- CFG: for edits that must preserve the picture start at `CFG=1.0` (the negative prompt is ignored there, so leave it empty); if the edit comes out too weak, try 3 to 4. For a new scene from a reference use the normal values below.

## Size and parameters

Sizes for `S[n]`: 3:2 `1248x832`, 2:3 `832x1248`, 4:3 `1152x864`, 3:4 `864x1152`, 16:9 `1536x864`, 9:16 `864x1536`, 1:1 `1024x1024`. Pick from the subject; horizontal scenes default to 3:2, vertical ones to 2:3.

`CFG` and `STEPS` apply to the whole run. Default `CFG=4.0 STEPS=40`. Starting points: photorealism 3.5 to 4, illustration and graphics 4 to 5, a lot of exact text or strict layout 5 to 6, quick drafts `STEPS=20`. An image that looks burnt or harsh wants a lower CFG; one that ignores the prompt wants a higher one. If prompts in one batch need different values, split the launch by prompt numbers.

Transparent background: wrap the description as `This is an RGBA image with transparency. … The image has alpha channel and the background is transparent.` and do not describe a background.

## Reply format

The block, the launch line, then one to three lines on what you decided yourself. The comment line and the notes are in the language of the user; prompts and negative prompts are always English. Number from 1 unless the user names the slots. Do not pick seeds.

````bash
# ── 1 ── short description
P[1]='<prompt>'
N[1]='<negative prompt or empty>'
S[1]=1248x832
````

````bash
CFG=4.0 STEPS=40 ./qwen-batch.sh
````

With a reference the launch line carries it: `REF=/path/to/image.png CFG=1.0 ./qwen-batch.sh`.
