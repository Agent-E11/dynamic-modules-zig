# Dynamic Modules in Zig

The idea is inspired by [the Sensor Watch default firmware](https://github.com/joeycastillo/Sensor-Watch/),
Movement, and how any developer could create [their own watch face](https://github.com/joeycastillo/Sensor-Watch/tree/main/movement/watch_faces/complication),
and as long as the face implemented certain functions, they could add their
custom face to the include directory, modify the build script and source files
a little, and build their own custom firmware with their face included.

I've started learning Zig, and more recently its build system, and thought
there might be a way to implement this sort of "dynamic module" system using
`build.zig` in a much more "user friendly" way than the way Movement does it
(possibly making it so that all the user has to do is add their module to
a `modules/` directory).

---

# Contributing

> Note: read [the license](./LICENSE)

I won't make any promises about accepting PRs, but if you do fork this repo and
figure out something cool, please tell me, I would love to hear about it!
