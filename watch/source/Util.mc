using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Attention as Att;
using Toybox.Lang;

// Paleta (MIP 64 cores: canais 00/55/AA/FF)
const C_BG = 0x000000;
const C_TXT = 0xFFFFFF;
const C_MUT = 0xAAAAAA;
const C_DIM = 0x555555;
const C_ACC = 0xFF5500;
const C_OK = 0x00FF55;
const C_WARN = 0xFFAA00;
const C_BAD = 0xFF0000;
const C_INFO = 0x55AAFF;

// kg em centésimos -> "22.5"
function fmtKg(k100) {
    if (k100 == null) { return "0"; }
    var k = k100.toNumber();
    if (k % 100 == 0) { return (k / 100).format("%d"); }
    if (k % 10 == 0) { return (k / 100).format("%d") + "." + ((k % 100) / 10).format("%d"); }
    return (k / 100.0).format("%.2f");
}

function fmtSec(s) {
    if (s < 0) { s = 0; }
    if (s >= 60) { return (s / 60).format("%d") + ":" + (s % 60).format("%02d"); }
    return s.format("%d");
}

function fmtMMSS(s) {
    if (s < 0) { s = 0; }
    return (s / 60).format("%d") + ":" + (s % 60).format("%02d");
}

function clockStr() {
    var t = Sys.getClockTime();
    return t.hour.format("%02d") + ":" + t.min.format("%02d");
}

function vibe(pattern) {
    if (Att has :vibrate) {
        var arr = [];
        for (var i = 0; i + 1 < pattern.size(); i += 2) {
            arr.add(new Att.VibeProfile(pattern[i], pattern[i + 1]));
        }
        try { Att.vibrate(arr); } catch (e) { }
    }
}

function tone(t) {
    if (Att has :playTone) {
        try { Att.playTone(t); } catch (e) { }
    }
}

function light() {
    if (Att has :backlight) {
        try { Att.backlight(true); } catch (e) { }
    }
}

// Quebra o texto em até maxLines linhas que cabem em maxW.
function wrapText(dc, text, font, maxW, maxLines) {
    var out = [];
    if (text == null) { return out; }
    var words = splitWords(text);
    var line = "";
    var i = 0;
    while (i < words.size()) {
        var w = words[i];
        var test = line.length() == 0 ? w : line + " " + w;
        if (dc.getTextWidthInPixels(test, font) <= maxW) {
            line = test;
            i++;
        } else if (line.length() == 0) {
            out.add(ellipsize(dc, w, font, maxW));
            i++;
            line = "";
            if (out.size() >= maxLines) { return out; }
        } else {
            out.add(line);
            line = "";
            if (out.size() >= maxLines) { break; }
        }
    }
    if (out.size() < maxLines && line.length() > 0) {
        out.add(line);
        i = words.size();
    }
    if (i < words.size() && out.size() > 0) {
        var last = out[out.size() - 1];
        out[out.size() - 1] = ellipsize(dc, last + "...", font, maxW);
    }
    return out;
}

function splitWords(text) {
    var res = [];
    var s = text;
    var idx = s.find(" ");
    while (idx != null) {
        if (idx > 0) { res.add(s.substring(0, idx)); }
        s = s.substring(idx + 1, s.length());
        idx = s.find(" ");
    }
    if (s.length() > 0) { res.add(s); }
    return res;
}

function ellipsize(dc, text, font, maxW) {
    if (dc.getTextWidthInPixels(text, font) <= maxW) { return text; }
    var t = text;
    while (t.length() > 1 && dc.getTextWidthInPixels(t + "...", font) > maxW) {
        t = t.substring(0, t.length() - 1);
    }
    return t + "...";
}

function heart(dc, x, y, color) {
    dc.setColor(color, Gfx.COLOR_TRANSPARENT);
    dc.fillCircle(x - 3, y - 2, 3);
    dc.fillCircle(x + 3, y - 2, 3);
    dc.fillPolygon([[x - 6, y - 1], [x + 6, y - 1], [x, y + 6]]);
}

function check(dc, x, y, s, color) {
    dc.setColor(color, Gfx.COLOR_TRANSPARENT);
    dc.setPenWidth(3);
    dc.drawLine(x - s, y, x - s / 3, y + s * 2 / 3);
    dc.drawLine(x - s / 3, y + s * 2 / 3, x + s, y - s * 2 / 3);
    dc.setPenWidth(1);
}

// Anel no aro da tela: fração de 0 a 1, no sentido horário a partir do topo.
function ring(dc, frac, color, width) {
    var w = dc.getWidth();
    var h = dc.getHeight();
    var cx = w / 2;
    var cy = h / 2;
    var r = (w < h ? w : h) / 2 - width / 2 - 1;
    dc.setPenWidth(width);
    dc.setColor(C_DIM, Gfx.COLOR_TRANSPARENT);
    dc.drawCircle(cx, cy, r);
    if (frac > 0) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        if (frac >= 0.999) {
            dc.drawCircle(cx, cy, r);
        } else {
            var end = 90 - (360 * frac).toNumber();
            if (end == 90) { end = 89; }
            dc.drawArc(cx, cy, r, Gfx.ARC_CLOCKWISE, 90, end);
        }
    }
    dc.setPenWidth(1);
}

// Pequena marca no aro ao lado de um botão (ângulo em graus, 0 = 3h, anti-horário).
function btnMark(dc, deg, color) {
    var w = dc.getWidth();
    var cx = w / 2;
    var cy = dc.getHeight() / 2;
    var r = cx - 3;
    dc.setPenWidth(5);
    dc.setColor(color, Gfx.COLOR_TRANSPARENT);
    dc.drawArc(cx, cy, r, Gfx.ARC_COUNTER_CLOCKWISE, deg - 6, deg + 6);
    dc.setPenWidth(1);
}

function hrColor(hr, zones) {
    if (hr == null || zones == null || zones.size() < 6) { return C_TXT; }
    if (hr >= zones[4]) { return C_BAD; }
    if (hr >= zones[3]) { return C_ACC; }
    if (hr >= zones[2]) { return C_WARN; }
    if (hr >= zones[1]) { return C_OK; }
    return C_INFO;
}

function toInt(v, d) {
    if (v == null) { return d; }
    if (v instanceof Lang.Number) { return v; }
    if (v instanceof Lang.Long || v instanceof Lang.Float || v instanceof Lang.Double) { return v.toNumber(); }
    if (v instanceof Lang.String) { var n = v.toNumber(); return n == null ? d : n; }
    if (v instanceof Lang.Boolean) { return v ? 1 : 0; }
    return d;
}

function toStr(v, d) {
    if (v == null) { return d; }
    if (v instanceof Lang.String) { return v; }
    return v.toString();
}
