const Self = @This();

const std = @import("std");
const log = std.log.scoped(.scroller);

const config = @import("config");
const Context = @import("../context.zig");
const Output = @import("../output.zig");
const Window = @import("../window.zig");

outer_gap: i32,
inner_gap: i32,
mfact: f32,
preset_widths: []const f32 = &.{},

pub fn cycle_preset_mfact(self: *const Self, output: *Output, forward: bool) ?f32 {
    if (self.preset_widths.len == 0) return null;
    const context = Context.get();
    const window = context.focus_top_in(output, false) orelse return null;
    if (window.floating) return null;

    const current = window.scroller_mfact;
    var index: usize = 0;
    for (self.preset_widths, 0..) |p, i| {
        if (p == current) {
            index = i;
            break;
        }
    } else {
        index = if (forward) 0 else self.preset_widths.len - 1;
    }

    if (forward) {
        index = if (index + 1 >= self.preset_widths.len) 0 else index + 1;
    } else {
        index = if (index == 0) self.preset_widths.len - 1 else index - 1;
    }
    return self.preset_widths[index];
}

pub fn default_preset_mfact(self: *const Self) ?f32 {
    if (self.preset_widths.len == 0) return null;
    return self.preset_widths[0];
}

pub fn arrange(self: *const Self, output: *Output) void {
    log.debug("<{*}> arrange windows in output {*}", .{ self, output });

    const context = Context.get();
    const cfg = config.get();

    const focus_top = context.focus_top_in(output, true) orelse return;

    const exclusive_width = output.exclusive_width();
    const exclusive_height = output.exclusive_height();
    const border = cfg.border.width;
    const usable_width = exclusive_width - 2 * self.outer_gap - 2 * border;
    const usable_height = exclusive_height - 2 * self.outer_gap - 2 * border;

    const master_width: i32 = @intFromFloat(@as(f32, @floatFromInt(usable_width)) * focus_top.scroller_mfact);
    const height = usable_height;
    const y = self.outer_gap + border;

    const left = @max(self.outer_gap + border, blk: {
        var link = &focus_top.link;
        while (link.prev.? != &context.windows.link) {
            defer link = link.prev.?;
            const window: *Window = @fieldParentPtr("link", link.prev.?);
            if (window.is_visible_in(output) and !window.floating) {
                break :blk switch (window.scroller_x orelse break :blk self.outer_gap + border) {
                    .x => |x| x,
                    .center => window.x,
                } + window.width + self.inner_gap;
            }
        }
        break :blk self.outer_gap + border;
    });
    const right = exclusive_width - border - self.outer_gap - master_width;
    const master_x = blk: {
        const x = if (focus_top.scroller_x) |scroller_x| switch (scroller_x) {
            .x => |x| x,
            .center => break :blk @divFloor(exclusive_width - focus_top.width, 2),
        } else left;
        break :blk if (x > right) right else left;
    };
    if (focus_top.scroller_x == null or focus_top.scroller_x.? == .x) {
        focus_top.scroller_x = .{ .x = master_x };
    }

    focus_top.unbound_move(master_x, y);
    focus_top.unbound_resize(master_width, height);

    {
        var link = &focus_top.link;
        var x = master_x;
        while (link.prev.? != &context.windows.link) {
            defer link = link.prev.?;
            const window: *Window = @fieldParentPtr("link", link.prev.?);
            if (!window.is_visible_in(output) or window.floating) continue;

            x -= self.inner_gap;

            const width: i32 = @intFromFloat(@as(f32, @floatFromInt(usable_width)) * window.scroller_mfact);

            x -= width;
            window.scroller_x = .{ .x = x };
            window.unbound_move(x, y);
            window.unbound_resize(width, height);
        }
    }

    {
        var link = &focus_top.link;
        var x = master_x + master_width;
        while (link.next.? != &context.windows.link) {
            defer link = link.next.?;
            const window: *Window = @fieldParentPtr("link", link.next.?);
            if (!window.is_visible_in(output) or window.floating) continue;

            x += self.inner_gap;

            const width: i32 = @intFromFloat(@as(f32, @floatFromInt(usable_width)) * window.scroller_mfact);

            window.scroller_x = .{ .x = x };
            window.unbound_move(x, y);
            window.unbound_resize(width, height);
            x += width;
        }
    }
}
