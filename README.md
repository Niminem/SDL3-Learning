# SDL3-Learning

## To The Nim Communiy

This is my collection of examples (and soon ports) for SDL3's new GPU API.

As of 2/23/25 I only have examples ready in `/my_examples`.

This repo is just for learning purposes at the moment and figured it would be best to
share examples publicly. Pretend this repository is more like a lab- there's going
to be s***t everywhere.

Each example you see in `/my_examples` was built from watching an
Odin programming language tutorial on YouTube: https://www.youtube.com/watch?v=tfc3vschDVw

Highly encourage you to watch it as you read through the codebase. He
goes into enough detail to leverage the [official SDL GPU Docs](https://wiki.libsdl.org/SDL3/CategoryGPU)
(which is VERY good). Highly encourage you to use ChatGPT as well if you're new to graphics
programming as I am. That's what helped create this Nim port when I got stuck, and learned
a lot about graphics programming along the way.

NOTE:
The SDL3 wrapper located in `vendor/sdl3` is from https://github.com/transmutrix/nim-sdl3.
I made a local version here because it was manually wrapped by Transmutrix and there are constant
tiny discrepancies with the API to tweak. I'm making changes here for now and will sync it with
the main repository at a later time.