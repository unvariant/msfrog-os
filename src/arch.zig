pub fn hang() noreturn {
    while (true) {}
}

// compile timer helper to convert u8 strings to u16 strings
pub fn normalize(comptime string: []const u8) [:0]const u16 {
    var new = [_:0]u16{0} ** (string.len + 1);
    for (0..string.len) |i| {
        new[i] = string[i];
    }
    return &new;
}
