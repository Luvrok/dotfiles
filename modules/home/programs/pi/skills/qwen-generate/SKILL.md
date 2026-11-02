---
name: qwen-generate
description: Generate images on this machine with the local Qwen-Image-2.1 model, from a text idea or from a reference image file. Writes the prompt, negative prompt, size and parameters, starts the render in the background with the bundled launcher script and ends the turn without waiting for the picture. Use when the user asks to generate, draw or make an image, picture, photo, illustration, logo or poster, to edit, restyle or reproduce an image file given as a path or as REF=path, or for a batch of pictures on a theme.
---

# Images with Qwen-Image-2.1 (qwen-gen.sh)

The user gives an idea for a picture, in any language, sometimes together with an image file. You write the prompt, start the render with one call of the launcher, and reply in a few lines. Do not ask clarifying questions, and do not read files or run other commands unless the user asks. Never wait for the picture: see Launching.

## When the request and this file disagree

Most of this file describes defaults for the case where the user said nothing. When the user asks for something a default advises against, do what the user asks. Typical cases: a longer prompt, a detailed description of one subject, freedom in part of the picture, a look at the reference file. Settle each such point once and move on. Do not come back to it.

Three things are not defaults and hold whatever the user says: the Hard limits, passing `--ref` whenever there is an image file, and not waiting for the result.

## First: is there an image file in the request?

Before anything else, look for a path to an image: `/home/user/photo.png`, `~/ref.jpg`, `REF=/path/ref.jpg`, or a file named next to the words reference, референс, исходник. If there is one, this is a reference job:

- Pass the path with `--ref`, as the user wrote it, without the `REF=` prefix. Without `--ref` the image model never receives the picture, and the result has nothing to do with it.
- The image model reads the file itself and sees everything in it. Your prompt tells it what to do with the picture, so you can write a good prompt without seeing the file. If the user asks you to look at the image and you can read images, read the file once and use what you see.
- Do not guess what is in the image. A detail you get wrong, such as clothes, weapons or landscape, replaces what is really there. Name only what the user told you or what you clearly saw. Point at anything else without naming it: `the object in his hand`, `the animal`.
- Do not pass `--size`: the result takes the format of the reference.
- Do not ask the user to describe the picture, and do not say in the reply that you cannot see it.

The prompt of a reference job is written by the section With a reference image. Without an image file, skip that section.

## Your creative room

Only what the user states is fixed: named objects, counts, colors, positions, exact text. Carry those over unchanged. Everything else is yours to invent, and you are expected to: the setting, the moment, the angle, the weather, the light, small telling details, the mood. Prefer a specific, surprising picture over a safe generic one. When asked for several pictures on a theme, make them clearly different pictures, not one scene reworded.

With a reference image this freedom covers the parts the user left open: see Locked and free.

## Writing the prompt

This section is for a picture made from text alone. There the model responds best to one English paragraph that describes the finished image as an observer would, not to commands or tag lists. Whatever you leave undescribed, the model fills in on its own.

- Open by naming the kind of image, its style, the subject, and the setting or palette: `A wide realistic photograph of …`, `A vertical flat-vector poster of …`.
- Then place things. Say where each important element sits (on the left, in the foreground, in the upper-right corner, behind the subject) so the composition is not left to chance. A full scene has eight to fourteen placed elements, spread over the corners, the edges and the center, not gathered in the middle.
- Describe through what is visible: materials, colors with a modifier (deep navy, pale cream), each garment, posture, expression. Enumerate instead of writing "various items", with counts as words. Give the age of a person as a life stage or a decade, not a number.
- Give the light a sentence: where it comes from, how hard or soft it is, what shadows and highlights it leaves.
- Close with one sentence on the overall composition and mood.
- Text that must appear in the image goes in straight double quotes, character for character, with where it sits and what it looks like: weight, color, size and medium, such as paint, neon or engraving: `a bold white headline across the top reads "…"`. Keep it in its own script, one language per string. A prompt with text ends with `No other text appears in the image.` Signs that should not be readable are described as blurred or too small to read. Do not invent readable text the user did not ask for.
- Present tense, declarative. No `create`, `make`, `should`. No quality boosters like `masterpiece` or `8K`. No sizes or aspect ratios in the text.
- Length follows the scene: roughly 150 to 450 words. A single object can be short; a dense scene with text needs more.

## Hard limits (sd.cpp and bash)

- Prompt and negative prompt are each one line, always in English.
- Never use the apostrophe `'`: write `the hat of the man`, `do not`.
- Never use `( ) [ ] < >`. The launcher rejects them.
- Double quotes only around text that is written in the image.

## Negative prompt

Optional, and it only works when cfg is above 1. A short comma-separated list of what could wrongly appear in this image: the opposite style, typical defects, unwanted processing. Leave `--neg` out when there is nothing specific to exclude.

When hands are large in the frame, as in a close-up, a portrait with hands or a hand holding a product, say in the prompt what each hand does and add `natural hand posture, five fingers`, with `extra fingers, deformed hands` in the negative prompt. In a wide scene with small figures, skip this.

## With a reference image

The prompt is an instruction about the picture, not a description of it from scratch. Call the picture `the image`. The Hard limits still apply; the eight to fourteen placed elements of Writing the prompt do not.

### Locked and free

Before writing, sort the picture into two parts.

- **Locked**: what must stay as it is. In an edit of one thing, that is everything except the thing. In a restyle where the user says nothing more, that is the whole layout.
- **Free**: what the user leaves open, either in words (room for imagination, the rest is up to you) or by fixing only some things (keep the poses of the people). The free part is yours to invent and describe, as in Your creative room.

One Keep clause names the locked part and nothing else: `Keep the position, pose and proportions of the two riders exactly as they are in the image.` Never list a free part in the Keep clause. When nothing is free, the clause covers everything: the composition, the framing, and the position, pose and proportions of every figure and object.

### Two kinds of description

- **Where things are**: placement, pose, count, framing. This comes from the image. Do not restate it for locked parts: restating makes the model redraw and move them. The Keep clause covers it.
- **What things look like**: surface, material, anatomy, light, camera. A new look changes exactly this, so describe it as fully as the picture needs. It moves nothing.

### The jobs

- **Changing something in the picture.** Lead with the operation and say exactly what changes, concretely and strongly enough that the result cannot be mistaken for the original. Then the Keep clause for everything else. In this job, add nothing the user did not ask for, and do not fix defects the user did not mention. Example: `Replace the overcast sky in the image with a clear deep-blue evening sky with a thin crescent moon. Keep the buildings, the street, the people and the framing exactly as they are in the image.`
- **The same picture in another look**: a painting as a photograph, a photo as anime, "repeat it one to one, but realistic". Name the new medium and what it looks like: surfaces, light, camera, noise, blur. The wishes of the user about the look go here, and what must stay clearly visible gets its own sentence. Then the Keep clause. Example: `Turn the image into a realistic photograph of the same scene, taken on a phone at dusk: real skin, cloth and wet asphalt, mixed street light, light noise, slight motion blur at the edges of the frame. The faces stay in sharp focus. Keep the composition, the framing, and the position, pose and proportions of every figure and object exactly as they are in the image.`
- **Another look with a free part.** The user fixes some things and leaves the rest open. Write the new look, then the Keep clause for the locked part only, then describe the free part as a scene of your own. Example: `Turn the image into a realistic photograph taken on a digital camera in overcast daylight: real skin, worn wool and leather, a wet horse coat, fine sensor noise, slight softness in the far background. Keep the position, pose and proportions of the rider and the horse exactly as they are in the image. The land around them is a real river ford: shallow brown water over round stones, trampled mud on the near bank, bare willows and low mist on the far one.`
- **A new picture of the same subject.** Point at the subject (`the woman from the image`, `the product from the image`) instead of describing its features, and build the new scene around it with full freedom: setting, light, composition.

For every job:

- State things affirmatively and decisively.
- When something is removed, say what is seen in its place. When the frame is extended beyond the edges of the image, say so in those words.
- Match the camera words to the camera the user names: sensor noise for a digital camera, grain for film.

### Marks of the old medium

When a drawing or painting becomes a photograph, a signature, caption, frame, paper edge or canvas texture belongs to the old medium. Remove it without being asked and say what is seen in its place: `Remove the caption in the lower-left corner, leaving only dry grass in its place.`

### Subjects the image model draws badly

An extinct animal, a rare machine, an unusual instrument, or anything the user asks to describe well. The image shows the model where the subject is; your words tell it what the subject is as a real thing. Give it three to five sentences: the overall build and its size against something else in the picture, each distinctive part, the surface and texture, the color. Use what you know about the subject, not only what the picture shows. Its place and pose still come from the image.

The same goes for people the user wants to look a certain way, such as true to a period: describe the build, skin, hair and what they wear or carry as real things.

### Length

Two to five sentences by default. The prompt grows when the user asks for a detailed or substantial prompt, when a subject needs describing as above, or when there is a free part to invent. Then it runs as long as the content needs, up to about 250 words. The extra words go to what things look like and to the free part, never to the placement of locked parts.

### Size and cfg with a reference

- Size: no `--size`, the result keeps the proportions of the reference. Only when the user asks for a different format or a wider frame, pass `--size` together with `--reframe`.
- cfg: an edit that changes one thing and must preserve the rest starts at `--cfg 1.0` (the negative prompt is ignored there, so leave it out); if the user says the edit came out too weak, try 2 to 3. Another look redraws every pixel, so it takes the normal value of the new look from the section below, 2 to 3 for a photograph, with a negative prompt that names the old medium: `illustration, painting, drawing`. A new scene from a reference also uses the normal values.

## Size and parameters

Sizes for `--size`: 3:2 `1248x832`, 2:3 `832x1248`, 4:3 `1152x864`, 3:4 `864x1152`, 16:9 `1536x864`, 9:16 `864x1536`, 1:1 `1024x1024`. Pick from the subject; horizontal scenes default to 3:2, vertical ones to 2:3. Larger sizes only when the user names one.

Default `--cfg 2.5 --steps 40`. Starting points for cfg: photorealism 2 to 3, illustration, painting and anime 3 to 4, a lot of exact text or strict layout 4 to 5. Quick drafts: `--steps 20`. One careful render, when the user asks to do it once and well: `--steps 50`.

What cfg does on this setup: a higher value follows the prompt more closely and makes small detail crisper, but it also draws faint regular stripes along edges and across fine parallel textures, and they grow with cfg. A scene full of planks, fences, siding, blinds, brickwork or woven fabric goes at the low end of its range. At 1.0 small faces and distant figures lose their features. An image that looks burnt, harsh or striped wants a lower cfg; one that ignores the prompt or comes out soft wants a higher one. Garbled text wants `--steps 50` first, then a higher cfg.

Choose cfg once. When two considerations pull in opposite directions, take the middle of the range and move on.

Do not pick seeds: the launcher does. Pass `--seed` only when the user names one, or to repeat an earlier picture with a single thing changed, so the two can be compared.

Transparent background: wrap the description as `This is an RGBA image with transparency. … The image has alpha channel and the background is transparent.` and do not describe a background.

## Launching

The launcher is `scripts/qwen-gen.sh` in the directory of this file. Call it by absolute path, once per picture:

````bash
bash ~/.pi/agent/skills/qwen-generate/scripts/qwen-gen.sh --size 1248x832 --cfg 2.5 --steps 40 --neg 'illustration, cartoon, plastic skin' --prompt 'A wide realistic photograph of …'
````

With an image file from the user:

````bash
bash ~/.pi/agent/skills/qwen-generate/scripts/qwen-gen.sh --ref /path/the/user/gave.jpg --cfg 2.5 --steps 40 --neg 'illustration, painting, drawing' --prompt 'Turn the image into … Keep … exactly as they are in the image.'
````

| Option | Value |
| --- | --- |
| `--prompt` | The prompt, in single quotes. Required. |
| `--neg` | The negative prompt, in single quotes. Optional. |
| `--size` | One of the sizes above. Leave out with `--ref`. |
| `--cfg`, `--steps` | As chosen above. |
| `--variants` | A number N: N pictures of the same prompt with different seeds. |
| `--seed` | Only in the two cases named above. |
| `--ref` | Path to the image file the user gave. Required whenever there is one. |
| `--reframe` | Only with `--ref` and `--size`: the user asked for a different format than the reference has. |

The launcher answers in under a second:

- `started: slot 41 | size 1248x832 | cfg 2.5 | steps 40 | seeds 500844755` means the job is queued and your work is done. A `note:` line under it is information, not an error.
- `error: …` means nothing was started. Fix what the message names and run the command again.
- `error: setup problem: …` means you cannot fix it. Show the line to the user and stop.

**Do not wait for the result.** The picture is rendered by a background process that cannot start while you are still working: the image model needs the GPU memory you occupy. It waits until you finish your reply, unloads you, and only then renders, which takes minutes. So after `started:` run no other command, no `sleep`, no `ls`, no look at the log or the output folder, and do not try to view or describe the image. It will not exist during this turn.

**Reply** in the language of the user: one line with the slot, size, cfg, steps and seed from the `started:` line, then at most two short lines on what you decided yourself. No prompt text.

**Several pictures:** one launcher call per picture, one after another, then one reply that lists all the slots. They queue up and render one at a time. Several variants of one picture are a single call with `--variants`.
