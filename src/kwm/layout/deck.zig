const Self = @This();

const std = @import("std");
const log = std.log.scoped(.deck);

const Context = @import("../context.zig");
const Output = @import("../output.zig");
const Window = @import("../window.zig");


inner_gap: i32,
outer_gap: i32,


pub fn arrange(self: *const Self, output: *Output) void {
    log.debug("<{*}> arrange windows in output {*}", .{ self, output });

    const context = Context.get();

    const master = blk: {
        var it = context.windows.safeIterator(.forward);
        while (it.next()) |window| {
            if (window.is_visible_in(output) and !window.floating) {
                break :blk window;
            }
        }
        return;
    };

    const w = output.exclusive_width() - 2 * self.outer_gap;
    const h = output.exclusive_height() - 2 * self.outer_gap;

    master.unbound_move(self.outer_gap, self.outer_gap);
    master.unbound_resize(w, h);

    // find top stack window in context.focus_stack
    {
        var found_stack_top = false;
        var it = context.focus_stack.safeIterator(.forward);
        while (it.next()) |window| {
            if (window == master) continue;
            if (!window.is_visible_in(output) or window.floating) continue;

            if (!found_stack_top) {
                found_stack_top = true;

                const master_w = @divFloor(w, 2);
                const stack_w = w - master_w - self.inner_gap;

                // correct master dimension
                master.unbound_resize(master_w, h);

                window.unbound_move(
                    self.outer_gap + master_w + self.inner_gap,
                    self.outer_gap,
                );
                window.unbound_resize(stack_w, h);
            } else {
                window.hide();
            }
        }
    }
}
