using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.Activity as Act;
using Toybox.UserProfile as UP;
using Toybox.Attention as Att;
using Toybox.WatchUi as Ui;
using Toybox.Lang;

const M_WAIT = 0;
const M_WARM = 1;
const M_SET = 2;
const M_REST = 3;
const M_TIMED = 4;
const M_ALLDONE = 5;
const M_PAIN = 6;
const M_SUM = 7;

// Índices de cada item da fila enviada pelo celular
const Q_KEY = 0;
const Q_NAME = 1;
const Q_SETNO = 2;
const Q_NSETS = 3;
const Q_KG = 4;
const Q_REPS = 5;
const Q_REST = 6;
const Q_TIME = 7;
const Q_STEP = 8;
const Q_SIDES = 9;
const Q_HOLDS = 10;

// Fases do cronômetro de exercício por tempo
const T_NONE = 0;
const T_READY = 1;
const T_COUNT = 2;
const T_RUN = 3;
const T_GAP = 4;
const T_OVER = 5;

class Model {
    // conexão
    var hasPhone = false;
    var lastPhone = 0;
    // treino
    var active = false;
    var wk = "";
    var stage = "";
    var warmName = "Aquecimento";
    var warmT0 = 0;
    var q = [];
    var done = 0;
    var total = 0;
    var etaMin = -1;
    var etaHH = "";
    var askRir = false;
    var spine = false;
    var nextKey = "";
    var nextName = "";
    var ov = {};
    var sel = 0;
    // descanso
    var restEnd = 0;
    var restDur = 0;
    var warned10 = false;
    var recovered = false;
    // RIR
    var rirKey = null;
    var rirLabel = "";
    var rirVal = 2;
    var rirShow = false;
    var rirDone = {};
    // cronômetro
    var tm = T_NONE;
    var tmT0 = 0;
    var tmSide = 1;
    var tmHold = 1;
    var tmOver = [];
    var tmLast = -1;
    // frequência cardíaca
    var hr = null;
    var zones = null;
    var setHrSum = 0;
    var setHrN = 0;
    var setHrMax = 0;
    // fim
    var painMode = false;
    var pain = 0;
    var sum = null;
    var prName = null;
    var prUntil = 0;
    var flash = null;
    var flashUntil = 0;
    // ajustes
    var hrAlert = true;
    var vib10 = true;

    function initialize() {
        try {
            zones = UP.getHeartRateZones(UP.HR_ZONE_SPORT_GENERIC);
        } catch (e) {
            zones = null;
        }
        var s = App.Storage.getValue("cfg");
        if (s instanceof Lang.Dictionary) {
            if (s["hr"] != null) { hrAlert = s["hr"]; }
            if (s["v10"] != null) { vib10 = s["v10"]; }
        }
        var st = App.Storage.getValue("st");
        if (st instanceof Lang.Dictionary) {
            restore(st);
        }
    }

    function now() { return Sys.getTimer(); }

    function mode() {
        if (sum != null) { return M_SUM; }
        if (painMode) { return M_PAIN; }
        if (!active) { return M_WAIT; }
        if (stage.equals("warm")) { return M_WARM; }
        if (tm != T_NONE) { return M_TIMED; }
        if (restEnd > now()) { return M_REST; }
        if (q.size() == 0) { return done >= total && total > 0 ? M_ALLDONE : M_WAIT; }
        return M_SET;
    }

    function cur() { return q.size() > 0 ? q[0] : null; }

    function curKg() {
        var it = cur();
        if (it == null) { return 0; }
        var o = ov[it[Q_KEY]];
        return o != null ? o[0] : toInt(it[Q_KG], 0);
    }

    function curReps() {
        var it = cur();
        if (it == null) { return 0; }
        var o = ov[it[Q_KEY]];
        return o != null ? o[1] : toInt(it[Q_REPS], 0);
    }

    function setVal(kg, reps) {
        var it = cur();
        if (it == null) { return; }
        if (kg < 0) { kg = 0; }
        if (reps < 0) { reps = 0; }
        ov[it[Q_KEY]] = [kg, reps];
    }

    function adjust(dir) {
        var it = cur();
        if (it == null) { return; }
        if (sel == 0) {
            var st = toInt(it[Q_STEP], 250);
            if (st <= 0) { st = 250; }
            setVal(curKg() + dir * st, curReps());
        } else {
            setVal(curKg(), curReps() + dir);
        }
    }

    function restLeft() {
        var l = restEnd - now();
        return l > 0 ? (l + 999) / 1000 : 0;
    }

    // ---------- estado vindo do celular ----------
    function applyState(d, outboxEmpty) {
        hasPhone = true;
        lastPhone = now();
        var ac = toInt(d["ac"], 0) == 1;
        if (!ac) {
            nextKey = toStr(d["nk"], "");
            nextName = toStr(d["nn"], "");
            if (active && outboxEmpty) {
                // o treino foi concluído ou descartado no celular
                var fx = d["fx"];
                active = false;
                q = [];
                restEnd = 0;
                tm = T_NONE;
                rirShow = false;
                painMode = false;
                if (fx instanceof Lang.Dictionary) {
                    finishLocal(fx, true);
                } else {
                    gRec.finish(true);
                }
            }
            persist();
            return;
        }
        if (!outboxEmpty) {
            // ainda temos ações locais a enviar: o estado do celular está atrasado
            return;
        }
        if (!active) {
            sum = null;
            painMode = false;
            ov = {};
            rirDone = {};
            done = 0;
        }
        active = true;
        wk = toStr(d["wk"], "");
        var ns = toStr(d["st"], "set");
        if (ns.equals("warm") && !stage.equals("warm")) { warmT0 = now() - toInt(d["el"], 0) * 1000; }
        stage = ns;
        warmName = toStr(d["wn"], "Aquecimento");
        done = toInt(d["dn"], 0);
        total = toInt(d["to"], 0);
        etaMin = toInt(d["em"], -1);
        etaHH = toStr(d["eh"], "");
        askRir = toInt(d["ar"], 0) == 1;
        spine = toInt(d["sp"], 0) == 1;
        var nq = d["q"];
        if (nq instanceof Lang.Array) {
            var oldKey = q.size() > 0 ? q[0][Q_KEY] : null;
            q = nq;
            var newKey = q.size() > 0 ? q[0][Q_KEY] : null;
            if (tm != T_NONE && (newKey == null || oldKey == null || !newKey.equals(oldKey))) { tm = T_NONE; }
        }
        // descanso: o celular manda quanto falta
        var rl = toInt(d["rl"], 0);
        var mine = restLeft();
        if (rl > 0) {
            var df = mine - rl;
            if (df < 0) { df = -df; }
            if (mine == 0 || df > 3) {
                restEnd = now() + rl * 1000;
                restDur = toInt(d["rd"], rl);
                if (restDur < rl) { restDur = rl; }
                warned10 = rl <= 10;
                recovered = false;
            }
        } else if (mine > 0) {
            restEnd = 0;
        }
        // RIR pendente
        var rk = d["rk"];
        if (rk != null && askRir && rirDone[rk] == null && (rirKey == null || !rirKey.equals(rk))) {
            rirKey = rk;
            rirLabel = toStr(d["rn"], "");
            rirShow = true;
        } else if (rk == null && rirKey != null && !rirShow) {
            rirKey = null;
        }
        var pr = d["pr"];
        if (pr != null && (prName == null || !prName.equals(pr))) {
            prName = pr;
            prUntil = now() + 6000;
            vibe([100, 120, 0, 80, 100, 120]);
        }
        if (!gRec.isOn()) { gRec.start("Treino " + wk); }
        persist();
    }

    // ---------- ações do usuário ----------
    function doneSet(reps) {
        var it = cur();
        if (it == null) { return; }
        var key = it[Q_KEY];
        var kg = curKg();
        if (reps == null) { reps = curReps(); }
        var rest = toInt(it[Q_REST], 0);
        var avg = setHrN > 0 ? setHrSum / setHrN : 0;
        var msg = {"t" => "done", "k" => key, "kg" => kg, "r" => reps, "rs" => rest, "hr" => avg, "hx" => setHrMax};
        gRec.setLap(kg, reps);
        q = q.slice(1, q.size());
        done += 1;
        ov.remove(key);
        sel = 0;
        tm = T_NONE;
        setHrSum = 0;
        setHrN = 0;
        setHrMax = 0;
        var remaining = total - done;
        if (rest > 0 && remaining > 0) {
            restEnd = now() + rest * 1000;
            restDur = rest;
            warned10 = false;
            recovered = false;
            if (askRir && toInt(it[Q_TIME], 0) == 0) {
                rirKey = key;
                rirLabel = shortName(it[Q_NAME]) + " " + fmtKg(kg) + "x" + reps;
                rirVal = 2;
                rirShow = true;
            }
        } else {
            restEnd = 0;
        }
        vibe([60, 80]);
        gLink.send(msg);
        persist();
    }

    function shortName(n) {
        var w = splitWords(toStr(n, ""));
        if (w.size() <= 2) { return toStr(n, ""); }
        return w[0] + " " + w[1];
    }

    function confirmRir() {
        if (rirKey == null) { rirShow = false; return; }
        gLink.send({"t" => "rir", "k" => rirKey, "v" => rirVal});
        rirDone[rirKey] = true;
        rirShow = false;
        rirKey = null;
        persist();
    }

    function skipRir() {
        if (rirKey != null) { rirDone[rirKey] = true; }
        rirShow = false;
        rirKey = null;
    }

    function addRest(sec) {
        var l = restLeft() + sec;
        if (l <= 0) {
            endRest(true);
            return;
        }
        restEnd = now() + l * 1000;
        if (l > restDur) { restDur = l; }
        if (l > 10) { warned10 = false; }
        gLink.send({"t" => "rest", "rs" => l});
    }

    function endRest(user) {
        restEnd = 0;
        gRec.restLap();
        if (user) {
            gLink.send({"t" => "rest", "rs" => 0});
        }
        flash = "VAI!";
        flashUntil = now() + 1500;
        persist();
    }

    function skipSet() {
        var it = cur();
        if (it == null) { return; }
        gLink.send({"t" => "skip", "k" => it[Q_KEY]});
        q = q.slice(1, q.size());
        done += 1;
        tm = T_NONE;
        persist();
    }

    function skipExercise() {
        var it = cur();
        if (it == null) { return; }
        var key = it[Q_KEY];
        var slot = key.substring(0, key.find("#"));
        gLink.send({"t" => "skipx", "k" => key});
        var left = toInt(it[Q_NSETS], 1) - toInt(it[Q_SETNO], 1) + 1;
        var nq = [];
        for (var i = 0; i < q.size(); i++) {
            var k = q[i][Q_KEY];
            if (!k.substring(0, k.find("#")).equals(slot)) { nq.add(q[i]); }
        }
        q = nq;
        done += left;
        tm = T_NONE;
        persist();
    }

    function warmDone() {
        stage = "set";
        gLink.send({"t" => "warm"});
        persist();
    }

    function requestStart() {
        gLink.send({"t" => "start"});
        flash = "Iniciando...";
        flashUntil = now() + 4000;
    }

    function startFinish() {
        if (spine) {
            painMode = true;
            pain = 0;
        } else {
            sendFinish(-1);
        }
    }

    function sendFinish(p) {
        painMode = false;
        var info = Act.getActivityInfo();
        var avg = 0;
        var mx = 0;
        var kc = 0;
        if (info != null) {
            if (info.averageHeartRate != null) { avg = info.averageHeartRate; }
            if (info.maxHeartRate != null) { mx = info.maxHeartRate; }
            if (info.calories != null) { kc = info.calories; }
        }
        gLink.send({"t" => "fin", "p" => p, "hr" => avg, "hx" => mx, "kc" => kc});
        finishLocal(null, true);
        active = false;
        q = [];
        restEnd = 0;
        tm = T_NONE;
        persist();
    }

    function finishLocal(fx, save) {
        var info = Act.getActivityInfo();
        var s = {};
        s["wk"] = wk;
        s["se"] = gRec.sets;
        s["vo"] = gRec.vol.toNumber();
        if (info != null) {
            if (info.elapsedTime != null) { s["mi"] = (info.elapsedTime / 60000).toNumber(); }
            if (info.averageHeartRate != null) { s["hr"] = info.averageHeartRate; }
            if (info.maxHeartRate != null) { s["hx"] = info.maxHeartRate; }
            if (info.calories != null) { s["kc"] = info.calories; }
        }
        if (fx != null) {
            if (fx["mi"] != null) { s["mi"] = fx["mi"]; }
            if (fx["se"] != null) { s["se"] = fx["se"]; }
            if (fx["vo"] != null) { s["vo"] = fx["vo"]; }
            if (fx["pr"] != null) { s["pr"] = fx["pr"]; }
            if (fx["wk"] != null) { s["wk"] = fx["wk"]; }
        }
        s["saved"] = gRec.isOn() && save;
        gRec.finish(save);
        sum = s;
        vibe([100, 150, 0, 100, 100, 150, 0, 100, 100, 300]);
        if (Att has :TONE_SUCCESS) { tone(Att.TONE_SUCCESS); }
    }

    // ---------- cronômetro de exercício por tempo ----------
    function timedStart() {
        tm = T_COUNT;
        tmT0 = now();
        tmLast = -1;
        if (tmSide < 1) { tmSide = 1; }
    }

    function timedEnter() {
        tm = T_READY;
        tmSide = 1;
        tmHold = 1;
        tmOver = [];
    }

    function timedTick() {
        var it = cur();
        if (it == null) { tm = T_NONE; return; }
        var sec = toInt(it[Q_TIME], 30);
        var holds = toInt(it[Q_HOLDS], 1);
        var t = now();
        if (tm == T_COUNT) {
            var l = 3 - (t - tmT0) / 1000;
            if (l <= 0) {
                tm = T_RUN;
                tmT0 = t;
                tmLast = -1;
                vibe([100, 300]);
                tone(Att.TONE_START);
            } else if (l != tmLast) {
                tmLast = l;
                vibe([50, 80]);
            }
        } else if (tm == T_RUN) {
            var left = sec - (t - tmT0) / 1000;
            if (left <= 0) {
                if (holds > 1 && tmHold < holds) {
                    tm = T_GAP;
                    tmT0 = t;
                    vibe([80, 150]);
                } else {
                    tm = T_OVER;
                    tmT0 = t;
                    vibe([100, 250, 0, 120, 100, 250]);
                    tone(Att.TONE_INTERVAL_ALERT);
                    light();
                }
            } else if (left <= 3 && left != tmLast) {
                tmLast = left;
                vibe([40, 60]);
            }
        } else if (tm == T_GAP) {
            if ((t - tmT0) / 1000 >= 5) {
                tmHold += 1;
                tm = T_RUN;
                tmT0 = t;
                vibe([100, 300]);
            }
        }
    }

    // START durante o cronômetro
    function timedPress() {
        var it = cur();
        if (it == null) { return; }
        var sec = toInt(it[Q_TIME], 30);
        var holds = toInt(it[Q_HOLDS], 1);
        var sides = toInt(it[Q_SIDES], 1);
        var t = now();
        if (tm == T_READY) { timedStart(); return; }
        if (tm == T_COUNT) { return; }
        if (tm == T_OVER && sides == 2 && tmSide == 1) {
            tmOver.add((t - tmT0) / 1000);
            tmSide = 2;
            timedStart();
            return;
        }
        var secs = 0;
        if (tm == T_OVER) {
            tmOver.add((t - tmT0) / 1000);
            var a = 0;
            for (var i = 0; i < tmOver.size(); i++) { a += tmOver[i]; }
            secs = holds > 1 ? holds : sec + a / tmOver.size();
        } else if (tm == T_RUN) {
            var el = (t - tmT0) / 1000;
            secs = holds > 1 ? tmHold - 1 + (el >= sec * 8 / 10 ? 1 : 0) : el;
        } else {
            secs = holds > 1 ? tmHold - 1 : 0;
        }
        tm = T_NONE;
        doneSet(secs);
    }

    // ---------- relógio de 1 s ----------
    function tick() {
        var info = Act.getActivityInfo();
        hr = info != null ? info.currentHeartRate : null;
        var m = mode();
        if (hr != null && (m == M_SET || m == M_TIMED)) {
            setHrSum += hr;
            setHrN += 1;
            if (hr > setHrMax) { setHrMax = hr; }
        }
        if (tm != T_NONE) { timedTick(); }
        if (restEnd > 0) {
            var l = restLeft();
            if (l <= 0) {
                restEnd = 0;
                rirShow = false;
                gRec.restLap();
                vibe([100, 400, 0, 150, 100, 400, 0, 150, 100, 600]);
                tone(Att.TONE_INTERVAL_ALERT);
                light();
                flash = "VAI!";
                flashUntil = now() + 2000;
                persist();
            } else {
                if (vib10 && !warned10 && l <= 10) {
                    warned10 = true;
                    vibe([60, 120, 0, 100, 60, 120]);
                }
                var thr = recoverHr();
                if (hrAlert && !recovered && hr != null && thr > 0 && hr <= thr && restDur - l >= 30) {
                    recovered = true;
                    vibe([40, 100]);
                }
            }
        }
    }

    function recoverHr() {
        if (zones != null && zones.size() >= 2) { return zones[1] + 5; }
        return 110;
    }

    // ---------- persistência ----------
    function persist() {
        var st = {
            "ac" => active, "wk" => wk, "stg" => stage, "wn" => warmName, "q" => q, "dn" => done, "to" => total,
            "eh" => etaHH, "em" => etaMin, "ar" => askRir, "sp" => spine, "nk" => nextKey, "nn" => nextName,
            "ov" => ov, "rd" => rirDone
        };
        try { App.Storage.setValue("st", st); } catch (e) { }
    }

    function restore(st) {
        active = st["ac"] == true;
        wk = toStr(st["wk"], "");
        stage = toStr(st["stg"], "");
        warmName = toStr(st["wn"], "Aquecimento");
        if (st["q"] instanceof Lang.Array) { q = st["q"]; }
        done = toInt(st["dn"], 0);
        total = toInt(st["to"], 0);
        etaHH = toStr(st["eh"], "");
        etaMin = toInt(st["em"], -1);
        askRir = st["ar"] == true;
        spine = st["sp"] == true;
        nextKey = toStr(st["nk"], "");
        nextName = toStr(st["nn"], "");
        if (st["ov"] instanceof Lang.Dictionary) { ov = st["ov"]; }
        if (st["rd"] instanceof Lang.Dictionary) { rirDone = st["rd"]; }
    }

    function saveCfg() {
        try { App.Storage.setValue("cfg", {"hr" => hrAlert, "v10" => vib10}); } catch (e) { }
    }
}
