using Toybox.Timer;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;

// Só entra na compilação de demonstração (demo.jungle): percorre as telas para gerar capturas.
(:demo)
var gDemo = null;

(:demo)
function demoHook() {
    gDemo = new DemoRunner();
}

(:demo)
class DemoRunner {
    var t;
    var i = 0;

    function initialize() {
        t = new Timer.Timer();
        t.start(method(:next), 3000, true);
        scene(0);
    }

    function next() {
        i += 1;
        if (i > 13) { i = 13; }
        scene(i);
        Ui.requestUpdate();
    }

    function item(key, name, no, n, kg, reps, rest, time, sides) {
        return [key, name, no, n, kg, reps, rest, time, 250, sides, 1];
    }

    function scene(n) {
        var md = gModel;
        var now = Sys.getTimer();
        md.demoHr = 128;
        if (n == 0) { md.hasPhone = false; md.active = false; }
        else if (n == 1) { md.hasPhone = true; md.nextKey = "B"; md.nextName = "Costas e bíceps · Core"; gLink.lastOk = now; }
        else if (n == 2) { md.active = true; md.wk = "A"; md.stage = "warm"; md.warmName = "Aquecimento de coluna"; md.warmT0 = now - 95000; }
        else if (n == 3) {
            md.stage = "set"; md.done = 5; md.total = 18; md.etaHH = "11:42"; md.sel = 0;
            md.q = [item("1#2", "Supino reto com barra", 3, 4, 3000, 10, 90, 0, 1),
                    item("1#3", "Supino reto com barra", 4, 4, 3000, 10, 90, 0, 1),
                    item("2#0", "Remada curvada pegada pronada", 1, 3, 4000, 12, 75, 0, 1)];
        }
        else if (n == 4) {
            md.sel = 1;
            md.q[0] = item("3#0", "Supino inclinado com halteres no banco", 1, 3, 2200, 12, 60, 0, 1);
        }
        else if (n == 5) { md.restEnd = now + 72000; md.restDur = 90; md.rirShow = false; md.demoHr = 142; }
        else if (n == 6) { md.demoHr = 96; }
        else if (n == 7) { md.rirShow = true; md.rirKey = "1#2"; md.rirLabel = "Supino reto 30x10"; md.rirVal = 2; md.demoHr = 120; }
        else if (n == 8) {
            md.rirShow = false; md.restEnd = 0;
            md.q = [item("6#0", "Prancha frontal", 1, 3, 0, 45, 45, 45, 1)];
            md.tm = T_RUN; md.tmT0 = now - 20000;
        }
        else if (n == 9) { md.tm = T_OVER; md.tmT0 = now - 7000; md.demoHr = 150; }
        else if (n == 10) { md.tm = T_NONE; md.q = []; md.done = 18; md.total = 18; }
        else if (n == 11) { md.painMode = true; md.pain = 3; }
        else if (n == 12) {
            md.painMode = false;
            md.sum = {"wk" => "A", "mi" => 41, "se" => 18, "vo" => 6240, "hr" => 124, "hx" => 163, "kc" => 312, "pr" => 2, "saved" => true};
        }
        else if (n == 13) {
            md.sum = null; md.active = true; md.done = 6; md.total = 18;
            md.q = [item("1#3", "Supino reto com barra", 4, 4, 3250, 8, 90, 0, 1)];
            md.prName = "Supino"; md.prUntil = now + 5000;
        }
    }
}
