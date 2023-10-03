const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;

const pin_config = rp2040.pins.GlobalConfiguration{
    .GPIO25 = .{
        .name = "led",
        .direction = .out,
    },
    .GPIO16 = .{
        .name = "pwmpin",
        .function = .PWM0_A,
    },
};
var p: rp2040.pins.Pins(pin_config) = undefined;

const myimportedfunction = @extern(*const fn (u32, u32) callconv(.C) u32, .{ .name = "myfunction" });


// ptrFromInt(0x18) must be a *u16, as 16-bit pointers are used in the bootrom.
// parameters: rom lookup table *u16, either data or func, letter code as u32
var rom_table_lookup: ?*const fn (*u16, u32) callconv(.C) u32 = undefined;
const rom_table_lookup_location = 0x18;
// parameters: led-pin-bitmask u32, disable-interface-mask
var optional_reset_to_usb: ?*const fn (u32, u32) callconv(.C) void = undefined;

pub fn main() void {
    const pins = pin_config.apply();
    pins.pwmpin.slice().set_wrap(10000);
    pins.pwmpin.set_level(4000);
    pins.pwmpin.slice().set_clk_div(16, 0);
    pins.led.put(0);
    p = pins;
    var result: u32 = myimportedfunction(1, 2);
    for (0..result) |_| {
        blinkstr("HOHO");
        pins.pwmpin.slice().disable();
    }
	// bootrom function lookup
	// the pointers are dereferenced here, which may only happen at runtime.
	// the results should not differ on rp2040 chips with the same hardware version, so could be hard-coded.
    const rom_func_table: *u16 = @ptrFromInt(@as(*u16, @ptrFromInt(0x0000_0014)).*);
    // unused const rom_data_table: *u16 = @ptrFromInt(@as(*u16,@ptrFromInt(0x0000_0016)).*);
    rom_table_lookup = @ptrFromInt(@as(*u16, @ptrFromInt(rom_table_lookup_location)).*);
    optional_reset_to_usb = @ptrFromInt(rom_table_lookup.?(rom_func_table, ('B' << 8) | 'U'));
    optional_reset_to_usb.?((1 << 25), 0);
}

const baseduration: u32 = 140 / 4 * 2;

const duration = enum {
    dit,
    dah,
    inter_element,
    inter_letter,
    inter_word,

    fn get(t: duration) u32 {
        return switch (t) {
            duration.dit, duration.inter_element => baseduration,
            duration.dah, duration.inter_letter => baseduration * 3,
            duration.inter_word => baseduration * 7,
        };
    }
};

fn blinkstr(s: []const u8) void {
    for (s) |v| {
        if (v == ' ') {
            wait(duration.inter_word);
        } else {
            blinkchr(v - 65);
        }
    }
}

fn blink(d: duration) void {
    emit(d, true);
}
fn wait(d: duration) void {
    emit(d, false);
}

fn emit(d: duration, high: bool) void {
    const t = duration.get(d);
    if (high) {
        p.led.put(1);
        p.pwmpin.slice().enable();
    } else {
        p.led.put(0);
        p.pwmpin.slice().disable();
    }
    time.sleep_ms(t);
}

fn blinkchr(c: u8) void {
    for (M[c]) |v| {
        if (v) {
            blink(duration.dah);
        } else {
            blink(duration.dit);
        }
        wait(duration.inter_element);
    }
    wait(duration.inter_letter);
}

fn morseStringToBoolArray(s: []const u8) []bool {
    var result: [s.len]bool = undefined;
    for (s, 0..) |letter, i| {
        var symbol: bool = blk: {
            if (letter == "-"[0]) {
                break :blk true;
            } else if (letter == "."[0]) {
                break :blk false;
            } else {
                unreachable;
            }
        };
        result[i] = symbol;
    }
    return &result;
}

fn generateMorsePattern(s: []const []const u8) []const []const bool {
    var result: [s.len][]const bool = undefined;
    for (s, 0..) |string, i| {
        result[i] = morseStringToBoolArray(string);
    }
    return &result;
}

const MorseStrings: []const []const u8 = &[_][]const u8{
".-", "-...", "-.-.", "-..", ".", "..-.", "--.", "....",
"..", ".---", "-.-", ".-..", "--", "-.", "---", ".--.",
"--.-", ".-.", "...", "-", "..-", "...-", "--.", "-..-",
"-.--", "..--" };
const M: []const []const bool = generateMorsePattern(MorseStrings);
