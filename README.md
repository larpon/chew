# chew - C HEader Wrapper

Crude and primitive helper module for C header lib V wrapping

Can be used as module and provides a basic command-line app for testing things out.

# Notes

Before you dive in:

* `chew` will usually only get you 60-90% of the way to a nice wrapper.
* `chew` will sometimes only get you 0% of the way, depending on how the C API code is written...
* `chew` isn't very well documented and probably won't ever be.
* Please keep your expectations low - `chew` uses, fairly, simple string parsing to achieve it's goal.
* If you start crying after using `chew`, don't blame me.
* If you start crying after using `chew`, because it worked, do tell me :).
* Use (and contribute to) [`c2v`](https://github.com/vlang/c2v) instead - it's a better tool for the job when it matures.
* I won't provide much support for `chew` - a few questions is OK - but it's a project
solely for personal use - I released it only because some *might* find it useful or interesting.
* It has helped me a lot - but may not help you a lot - use at your own risk and expense.
* Enjoy - if you dare use it :)

# Install

`git clone https://github.com/Larpon/chew.git ~/.vmodules`

# Usage

Currently `chew` expects that you setup your own V <-> C includes for each module you want to wrap.

Basically `chew` expects your V module to have a sub-folder named `c` with V files doing the actual C setup.
See [Larpon/miniaudio](https://github.com/Larpon/miniaudio/blob/master/c/miniaudio.c.v) for an example setup that works.

The output(s) of chew is then expected to live at the module root - where it can do `import c`.

Basic run:
`v run ~/.vmodules/chew <toml project config file> <header file or dir> <output dir>`

# Example

```
cd /tmp
git clone https://github.com/mackron/miniaudio.git
v run ~/.vmodules/chew ~/.vmodules/chew/configs/chew.miniaudio.toml ./miniaudio/miniaudio.h /tmp
cat /tmp/miniaudio.auto.c.v
# ... copy /tmp/miniaudio.auto.c.v to the V module wrapper root. E.g: cp miniaudio.auto.c.v ~/.vmodules/miniaudio
```

# Configs

Currently `chew` needs ~~a little~~ quite a lot of help understanding the C sources it parses to get everything going.

This help is expressed via TOML config files.

See `chew/configs` for example configs.
