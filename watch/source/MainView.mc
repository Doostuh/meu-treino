using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Timer;
using Toybox.Lang;

const RIR_TXT = ["Falhou ou quase", "No limite", "Ideal", "Sobrou um pouco", "Muito leve"];

class MainView extends Ui.View {
    var timer = null;
    var W = 240;
    var H = 240;
    var cx = 120;

    function initialize() {
        View.initialize();
    }

    function onShow() {
        if (timer == null) { timer = new Timer.Timer(); }
        timer.start(method(:onTick), 1000, true);
    }

    function onHide() {
        if (timer != null) { timer.stop(); }
    }

    function onTick() {
        gModel.tick();
        gLink.tick();
        Ui.requestUpdate();
    }

    function y(v) { return v * H / 240; }

    function onUpdate(dc) {
        W = dc.getWidth();
        H = dc.getHeight();
        cx = W / 2;
        dc.setColor(C_TXT, C_BG);
        dc.clear();
        var m = gModel.mode();
        if (m == M_SUM) { drawSum(dc); }
        else if (m == M_PAIN) { drawPain(dc); }
        else if (m == M_WAIT) { drawWait(dc); }
        else if (m == M_WARM) { drawWarm(dc); }
        else if (m == M_TIMED) { drawTimed(dc); }
        else if (m == M_REST) {
            if (gModel.rirShow) { drawRir(dc); } else { drawRest(dc); }
        }
        else if (m == M_ALLDONE) { drawAllDone(dc); }
        else { drawSet(dc); }
        drawFlash(dc);
    }

    // ---------- partes comuns ----------
    function text(dc, x, yy, font, s, color) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x, yy, font, s, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    function textL(dc, x, yy, font, s, color) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x, yy, font, s, Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    function textR(dc, x, yy, font, s, color) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x, yy, font, s, Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // linha do topo: FC, hora e bolinha de conexão
    function status(dc) {
        var yy = y(27);
        var hr = gModel.hr;
        var hs = hr == null ? "--" : hr.format("%d");
        var clk = clockStr();
        var f = Gfx.FONT_TINY;
        var wh = dc.getTextWidthInPixels(hs, f);
        var wc = dc.getTextWidthInPixels(clk, f);
        var tot = 14 + wh + 14 + wc + 10;
        var x0 = cx - tot / 2;
        heart(dc, x0 + 6, yy, C_BAD);
        textL(dc, x0 + 14, yy, f, hs, hrColor(hr, gModel.zones));
        textL(dc, x0 + 14 + wh + 14, yy, f, clk, C_MUT);
        var st = gLink.status();
        dc.setColor(st == 0 ? C_OK : (st == 1 ? C_WARN : C_BAD), Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(x0 + tot - 3, yy, 3);
    }

    function nameLines(dc, name, y0, maxLines) {
        var f = Gfx.FONT_MEDIUM;
        var lines = wrapText(dc, name, f, W - 50, 1);
        var full = splitWords(toStr(name, ""));
        if (lines.size() > 0 && lines[0].find("...") != null || full.size() > 0 && lines.size() == 0) {
            f = Gfx.FONT_SMALL;
            lines = wrapText(dc, name, f, W - 56, maxLines);
        }
        var lh = dc.getFontHeight(f);
        var yy = y0 - (lines.size() - 1) * lh / 2;
        for (var i = 0; i < lines.size(); i++) {
            text(dc, cx, yy + i * lh, f, lines[i], C_TXT);
        }
    }

    function drawFlash(dc) {
        var md = gModel;
        var t = Sys.getTimer();
        if (md.flash != null && t < md.flashUntil) {
            dc.setColor(C_ACC, Gfx.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - 70, y(196), 140, 30, 15);
            text(dc, cx, y(196) + 15, Gfx.FONT_SMALL, md.flash, C_BG);
        } else if (md.prName != null && t < md.prUntil) {
            dc.setColor(C_WARN, Gfx.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - 80, y(196), 160, 30, 15);
            text(dc, cx, y(196) + 15, Gfx.FONT_TINY, "RECORDE!", C_BG);
        }
    }

    // ---------- série ----------
    function drawSet(dc) {
        var md = gModel;
        var it = md.cur();
        if (it == null) { drawWait(dc); return; }
        var frac = md.total > 0 ? md.done.toFloat() / md.total : 0.0;
        ring(dc, frac, C_ACC, 7);
        status(dc);
        var timed = toInt(it[Q_TIME], 0);
        text(dc, cx, y(52), Gfx.FONT_XTINY, "SÉRIE " + toInt(it[Q_SETNO], 1) + " DE " + toInt(it[Q_NSETS], 1) + "  ·  " + md.wk, C_MUT);
        nameLines(dc, it[Q_NAME], y(86), 2);
        var kg = md.curKg();
        var reps = md.curReps();
        var vy = y(140);
        if (timed > 0) {
            var holds = toInt(it[Q_HOLDS], 1);
            var lbl = holds > 1 ? holds + " x " + timed + " s" : (toInt(it[Q_SIDES], 1) == 2 ? timed + " s / lado" : timed + " s");
            text(dc, cx, vy, Gfx.FONT_LARGE, lbl, C_TXT);
            text(dc, cx, y(170), Gfx.FONT_XTINY, kg > 0 ? fmtKg(kg) + " kg" : "START inicia o tempo", C_MUT);
        } else {
            var ks = fmtKg(kg);
            var rs = reps.format("%d");
            var fk = Gfx.FONT_NUMBER_MEDIUM;
            if (dc.getTextWidthInPixels(ks, fk) > 86) { fk = Gfx.FONT_NUMBER_MILD; }
            var lx = cx - 46;
            var rx = cx + 50;
            text(dc, lx, vy, fk, ks, md.sel == 0 ? C_ACC : C_TXT);
            text(dc, cx + 2, vy, Gfx.FONT_SMALL, "x", C_DIM);
            text(dc, rx, vy, Gfx.FONT_NUMBER_MEDIUM, rs, md.sel == 1 ? C_ACC : C_TXT);
            text(dc, lx, y(170), Gfx.FONT_XTINY, "kg", md.sel == 0 ? C_ACC : C_MUT);
            text(dc, rx, y(170), Gfx.FONT_XTINY, "reps", md.sel == 1 ? C_ACC : C_MUT);
            dc.setColor(C_ACC, Gfx.COLOR_TRANSPARENT);
            var bx = md.sel == 0 ? lx : rx;
            dc.fillRoundedRectangle(bx - 14, y(178), 28, 3, 1);
        }
        // próximo e previsão
        var nx = "";
        if (md.q.size() > 1) {
            var n2 = md.q[1];
            if (!toStr(n2[Q_NAME], "").equals(toStr(it[Q_NAME], ""))) { nx = "Próx: " + toStr(n2[Q_NAME], ""); }
        }
        if (nx.length() > 0) {
            text(dc, cx, y(196), Gfx.FONT_XTINY, ellipsize(dc, nx, Gfx.FONT_XTINY, W - 70), C_MUT);
        }
        if (md.etaHH.length() > 0) {
            text(dc, cx, y(214), Gfx.FONT_XTINY, "fim " + md.etaHH, C_DIM);
        }
        btnMark(dc, 30, C_OK);
    }

    // ---------- descanso ----------
    function drawRest(dc) {
        var md = gModel;
        var l = md.restLeft();
        var frac = md.restDur > 0 ? l.toFloat() / md.restDur : 0.0;
        var thr = md.recoverHr();
        var rec = md.hr != null && md.hr <= thr;
        ring(dc, frac, rec ? C_OK : C_INFO, 9);
        status(dc);
        text(dc, cx, y(56), Gfx.FONT_XTINY, rec ? "FC RECUPERADA" : "DESCANSO", rec ? C_OK : C_MUT);
        text(dc, cx, y(100), Gfx.FONT_NUMBER_HOT, fmtMMSS(l), l <= 10 ? C_WARN : C_TXT);
        var it = md.cur();
        if (it != null) {
            var nm = ellipsize(dc, toStr(it[Q_NAME], ""), Gfx.FONT_TINY, W - 96);
            text(dc, cx, y(150), Gfx.FONT_TINY, nm, C_TXT);
            var det = toInt(it[Q_TIME], 0) > 0 ? toInt(it[Q_TIME], 0) + " s" : fmtKg(md.curKg()) + " kg x " + md.curReps();
            text(dc, cx, y(172), Gfx.FONT_XTINY, ellipsize(dc, det + " · " + toInt(it[Q_SETNO], 1) + "/" + toInt(it[Q_NSETS], 1), Gfx.FONT_XTINY, W - 96), C_MUT);
        }
        textL(dc, 10, y(116), Gfx.FONT_XTINY, "+15", C_MUT);
        textL(dc, 20, y(150), Gfx.FONT_XTINY, "-15", C_MUT);
        textR(dc, W - 22, y(78), Gfx.FONT_XTINY, "pular", C_MUT);
        btnMark(dc, 30, C_INFO);
    }

    function drawRir(dc) {
        var md = gModel;
        var l = md.restLeft();
        var frac = md.restDur > 0 ? l.toFloat() / md.restDur : 0.0;
        ring(dc, frac, C_INFO, 9);
        text(dc, cx, y(40), Gfx.FONT_XTINY, "QUANTAS SOBRARAM?", C_MUT);
        text(dc, cx, y(62), Gfx.FONT_XTINY, ellipsize(dc, md.rirLabel, Gfx.FONT_XTINY, W - 70), C_TXT);
        var by = y(116);
        for (var i = 0; i < 5; i++) {
            var x = cx + (i - 2) * 38;
            var lb = i == 4 ? "4+" : i.format("%d");
            if (i == md.rirVal) {
                dc.setColor(C_ACC, Gfx.COLOR_TRANSPARENT);
                dc.fillCircle(x, by, 18);
                text(dc, x, by, Gfx.FONT_MEDIUM, lb, C_BG);
            } else {
                text(dc, x, by, Gfx.FONT_MEDIUM, lb, C_MUT);
            }
        }
        text(dc, cx, y(152), Gfx.FONT_SMALL, RIR_TXT[md.rirVal], C_TXT);
        text(dc, cx, y(180), Gfx.FONT_XTINY, "descanso " + fmtMMSS(l), C_INFO);
        textR(dc, W - 22, y(78), Gfx.FONT_XTINY, "ok", C_OK);
        textR(dc, W - 26, y(170), Gfx.FONT_XTINY, "pular", C_MUT);
        btnMark(dc, 30, C_OK);
    }

    // ---------- exercício por tempo ----------
    function drawTimed(dc) {
        var md = gModel;
        var it = md.cur();
        if (it == null) { drawWait(dc); return; }
        var sec = toInt(it[Q_TIME], 30);
        var holds = toInt(it[Q_HOLDS], 1);
        var sides = toInt(it[Q_SIDES], 1);
        var t = Sys.getTimer();
        var label = "";
        var big = "";
        var frac = 0.0;
        var col = C_TXT;
        var rc = C_ACC;
        if (md.tm == T_READY) {
            label = "PRONTO?";
            big = fmtSec(sec);
        } else if (md.tm == T_COUNT) {
            label = "PREPARE-SE";
            var c = 3 - (t - md.tmT0) / 1000;
            big = (c < 1 ? 1 : c).format("%d");
            col = C_WARN;
        } else if (md.tm == T_RUN) {
            var el = (t - md.tmT0) / 1000;
            var left = sec - el;
            big = fmtSec(left < 0 ? 0 : left);
            frac = el.toFloat() / sec;
            label = holds > 1 ? "REPETIÇÃO " + md.tmHold + " DE " + holds : (sides == 2 ? "LADO " + md.tmSide + " DE 2" : "SEGURE");
            if (left <= 3) { col = C_WARN; }
        } else if (md.tm == T_GAP) {
            var g = 5 - (t - md.tmT0) / 1000;
            big = (g < 0 ? 0 : g).format("%d");
            label = "DESCANSE";
            col = C_INFO;
        } else {
            big = "+" + ((t - md.tmT0) / 1000).format("%d");
            frac = 1.0;
            rc = C_OK;
            col = C_OK;
            label = sides == 2 && md.tmSide == 1 ? "LADO 1 OK · TEMPO EXTRA" : "TEMPO BATIDO · EXTRA";
        }
        ring(dc, frac, rc, 9);
        status(dc);
        text(dc, cx, y(54), Gfx.FONT_XTINY, label, md.tm == T_OVER ? C_OK : C_MUT);
        text(dc, cx, y(76), Gfx.FONT_TINY, ellipsize(dc, toStr(it[Q_NAME], ""), Gfx.FONT_TINY, W - 60), C_TXT);
        text(dc, cx, y(126), Gfx.FONT_NUMBER_HOT, big, col);
        var hint = md.tm == T_READY ? "START inicia" : (md.tm == T_OVER && sides == 2 && md.tmSide == 1 ? "START: lado 2" : "START conclui");
        text(dc, cx, y(176), Gfx.FONT_XTINY, hint, C_MUT);
        btnMark(dc, 30, C_OK);
    }

    // ---------- aquecimento ----------
    function drawWarm(dc) {
        var md = gModel;
        ring(dc, 0.0, C_ACC, 7);
        status(dc);
        text(dc, cx, y(56), Gfx.FONT_XTINY, "AQUECIMENTO  ·  " + md.wk, C_MUT);
        nameLines(dc, md.warmName, y(88), 2);
        var el = (Sys.getTimer() - md.warmT0) / 1000;
        if (md.warmT0 <= 0) { el = 0; }
        text(dc, cx, y(138), Gfx.FONT_NUMBER_MEDIUM, fmtMMSS(el), C_TXT);
        text(dc, cx, y(176), Gfx.FONT_XTINY, "Siga os exercícios no celular", C_MUT);
        text(dc, cx, y(196), Gfx.FONT_XTINY, ellipsize(dc, "START: musculação", Gfx.FONT_XTINY, W - 80), C_ACC);
        btnMark(dc, 30, C_OK);
    }

    // ---------- espera ----------
    function drawWait(dc) {
        var md = gModel;
        ring(dc, 0.0, C_ACC, 7);
        status(dc);
        if (md.active) {
            text(dc, cx, y(100), Gfx.FONT_SMALL, "Sincronizando", C_TXT);
            text(dc, cx, y(126), Gfx.FONT_XTINY, "com o celular...", C_MUT);
            return;
        }
        if (!md.hasPhone && md.pq.size() == 0) {
            text(dc, cx, y(64), Gfx.FONT_XTINY, "MEU TREINO", C_ACC);
            text(dc, cx, y(100), Gfx.FONT_SMALL, "Abra o app", C_TXT);
            text(dc, cx, y(124), Gfx.FONT_SMALL, "no celular", C_TXT);
            text(dc, cx, y(158), Gfx.FONT_XTINY, "Procurando o celular...", C_MUT);
            return;
        }
        text(dc, cx, y(56), Gfx.FONT_XTINY, "PRÓXIMO TREINO", C_MUT);
        text(dc, cx, y(102), Gfx.FONT_LARGE, "Treino " + md.nextKey, C_ACC);
        var lines = wrapText(dc, md.nextName, Gfx.FONT_TINY, W - 60, 2);
        for (var i = 0; i < lines.size(); i++) {
            text(dc, cx, y(146) + i * dc.getFontHeight(Gfx.FONT_TINY), Gfx.FONT_TINY, lines[i], C_TXT);
        }
        text(dc, cx, y(198), Gfx.FONT_XTINY, md.pq.size() > 0 ? "START inicia · " + md.pt + " séries" : "START para iniciar", C_ACC);
        btnMark(dc, 30, C_OK);
    }

    function drawAllDone(dc) {
        var md = gModel;
        ring(dc, 1.0, C_OK, 7);
        status(dc);
        check(dc, cx, y(78), 16, C_OK);
        text(dc, cx, y(118), Gfx.FONT_MEDIUM, "TUDO FEITO!", C_TXT);
        text(dc, cx, y(146), Gfx.FONT_XTINY, md.done + " séries", C_MUT);
        text(dc, cx, y(180), Gfx.FONT_XTINY, "START: concluir treino", C_OK);
        btnMark(dc, 30, C_OK);
    }

    function drawPain(dc) {
        var md = gModel;
        var p = md.pain;
        var c = p <= 2 ? C_OK : (p <= 5 ? C_WARN : C_BAD);
        ring(dc, p / 10.0, c, 9);
        text(dc, cx, y(46), Gfx.FONT_XTINY, "COMO ESTÁ A LOMBAR?", C_MUT);
        text(dc, cx, y(112), Gfx.FONT_NUMBER_HOT, p.format("%d"), c);
        text(dc, cx, y(162), Gfx.FONT_XTINY, "0 sem dor  ·  10 dor forte", C_MUT);
        text(dc, cx, y(186), Gfx.FONT_XTINY, "START confirma", C_ACC);
        btnMark(dc, 30, C_OK);
    }

    function drawSum(dc) {
        var s = gModel.sum;
        ring(dc, 1.0, C_OK, 7);
        text(dc, cx, y(40), Gfx.FONT_XTINY, "TREINO " + toStr(s["wk"], "") + " CONCLUÍDO", C_OK);
        var mi = toInt(s["mi"], 0);
        text(dc, cx, y(78), Gfx.FONT_NUMBER_MEDIUM, mi.format("%d"), C_TXT);
        text(dc, cx, y(106), Gfx.FONT_XTINY, "minutos", C_MUT);
        var vo = toInt(s["vo"], 0);
        var vs = vo >= 1000 ? (vo / 1000.0).format("%.1f") + " t" : vo + " kg";
        text(dc, cx, y(132), Gfx.FONT_TINY, toInt(s["se"], 0) + " séries  ·  " + vs, C_TXT);
        var hr = toInt(s["hr"], 0);
        if (hr > 0) {
            text(dc, cx, y(156), Gfx.FONT_TINY, "FC " + hr + " méd  ·  " + toInt(s["hx"], 0) + " máx", C_TXT);
        }
        var kc = toInt(s["kc"], 0);
        var pr = toInt(s["pr"], 0);
        var l3 = (kc > 0 ? kc + " kcal" : "") + (pr > 0 ? (kc > 0 ? "  ·  " : "") + pr + " recorde" + (pr > 1 ? "s" : "") : "");
        if (l3.length() > 0) { text(dc, cx, y(178), Gfx.FONT_TINY, l3, pr > 0 ? C_WARN : C_TXT); }
        text(dc, cx, y(204), Gfx.FONT_XTINY, s["saved"] == true ? "Salvo no Garmin Connect" : "START para sair", C_MUT);
        btnMark(dc, 30, C_OK);
    }
}
