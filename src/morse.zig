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

const myimportedfunction = @extern(*const fn(u32,u32) callconv(.C) u32,.{.name="myfunction"});

// parameter: die lookuptabelle *u16, entweder data oder func, und der buchstabencode als u32
var optional_rom_table_lookup: ?*const fn (*u16,u32) callconv(.C) u32 = @ptrFromInt(0);
// parameter: led-pin-bitmaske u32, disable-interface-mask
var optional_reset_to_usb: ?*const fn(u32,u32) callconv(.C) void = @ptrFromInt(0);

pub fn main() void {
    const pins = pin_config.apply();
    pins.pwmpin.slice().set_wrap(10000);
    pins.pwmpin.set_level(4000);
    pins.pwmpin.slice().set_clk_div(16, 0);
    pins.led.put(0);
    p = pins;
    var result: u32 = myimportedfunction(1,2);
    for (0..result) |_| {
        blinkstr("SOS");
        pins.pwmpin.slice().disable();
    }
		
		// veraltet, in einer früheren version von zig gab es @intToPtr
		//go to usb boot
    //const find_bootrom_data = @intToPtr(*const fn (*u16, u32) u32, @intToPtr(*u16, 0x0000_0018).*);
    //const reset_to_usb: u32 = find_bootrom_data(@intToPtr(*u16, @intToPtr(*u16, 0x0000_0014).*), (('B' << 8) | 'U'));
    //@intToPtr(*const fn (u32, u32) void, reset_to_usb)(0, 0);
    
		// falsch:
		// const rom_table_lookup: *const fn (*u16, u32) callconv(.C) u32 = @as(*(*const fn (*u16, u32) callconv(.C) u32),@ptrFromInt(0x0000_0018)).*;
    // const reset_to_usb_location: u32 = rom_table_lookup(@as(**u16,@ptrFromInt(0x0000_0014)).*, (@as(u32,('B' << 8) | 'U')));
    // const reset_to_usb: *const fn(u32,u32) callconv(.C) void = @ptrFromInt(reset_to_usb_location);
		
    // richtig:
		const rom_func_table: *u16 = @ptrFromInt(@as(*u16,@ptrFromInt(0x0000_0014)).*);
		// const rom_data_table: *u16 = @ptrFromInt(@as(*u16,@ptrFromInt(0x0000_0016)).*);
		
		// richtig:
		// Ich habe 0x18, das ist die addresse von einem u16.
		// Also ist @ptrFromInt(0x18) ein *u16.
		// Also enthalten 0x18 und 0x19 die bytes.
		// Dereferenziert ist das dann ein u16.
		// Dieser u16 ist wiederum ein pointer auf eine Funktion.
		// Es ist wichtig zu beachten dass @ptrFromInt(0x18) NICHT ein *u32 ist,
		// denn sonst werden 0x18, 0x19, 0x20 und 0x21 als die bytes interpretiert,
		// die dann wiederum ein pointer sein sollen.
		// const rom_table_lookup: *const fn (*u16,u32) callconv(.C) u32 = @ptrFromInt(@as(*u16,@ptrFromInt(0x18)).*);
		// const reset_to_usb_location: u32 = rom_table_lookup(rom_func_table, ('B' << 8) | 'U');
		// const reset_to_usb: *const fn(u32,u32) callconv(.C) void = @ptrFromInt(reset_to_usb_location);
		// reset_to_usb((1<<25),0);
		
		// auch richtig:
		// wenn man die function pointer global definieren möchte, müssen sie uninitialisiert bleiben.
		// das ist aber verboten, also müssen sie optional sein.
		// weil sie später verändert werden, sind sie außerdem nicht const.
		// außerdem müssen sie beim aufrufen mit .? unoptionalisiert werden.
		optional_rom_table_lookup = @ptrFromInt(@as(*u16,@ptrFromInt(0x18)).*);
		optional_reset_to_usb = @ptrFromInt(optional_rom_table_lookup.?(rom_func_table, ('B' << 8) | 'U'));
		optional_reset_to_usb.?((1<<25),0);
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
            //blinkchr(26);
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

const M = [_][]const bool{
    &[_]bool{
        false,
        true,
    },
    &[_]bool{
        true,
        false,
        false,
        false,
    },
    &[_]bool{
        true,
        false,
        true,
        false,
    },
    &[_]bool{
        true,
        false,
        false,
    },
    &[_]bool{
        false,
    },
    &[_]bool{
        false,
        false,
        true,
        false,
    },
    &[_]bool{
        true,
        true,
        false,
    },
    &[_]bool{
        false,
        false,
        false,
        false,
    },
    &[_]bool{
        false,
        false,
    },
    &[_]bool{
        false,
        true,
        true,
        true,
    },
    &[_]bool{
        true,
        false,
        true,
    },
    &[_]bool{
        false,
        true,
        false,
        false,
    },
    &[_]bool{
        true,
        true,
    },
    &[_]bool{
        true,
        false,
    },
    &[_]bool{
        true,
        true,
        true,
    },
    &[_]bool{
        false,
        true,
        true,
        false,
    },
    &[_]bool{
        true,
        true,
        false,
        true,
    },
    &[_]bool{
        false,
        true,
        false,
    },
    &[_]bool{
        false,
        false,
        false,
    },
    &[_]bool{
        true,
    },
    &[_]bool{
        false,
        false,
        true,
    },
    &[_]bool{
        false,
        false,
        false,
        true,
    },
    &[_]bool{
        false,
        true,
        true,
    },
    &[_]bool{
        true,
        false,
        false,
        true,
    },
    &[_]bool{
        true,
        false,
        true,
        true,
    },
    &[_]bool{
        true,
        true,
        false,
        false,
    },
};
