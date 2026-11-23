using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Lang;

// Botões do Forerunner 245:
// START = ação principal (concluir série, pular descanso, confirmar)
// UP / DOWN = ajustar valor (carga/reps, descanso ±15 s, RIR)
// BACK = alternar carga/reps, pular pergunta
// Segurar UP = menu
class MainDelegate extends Ui.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() {
        var md = gModel;
        var m = md.mode();
        if (m == M_SUM) {
            Sys.exit();
        } else if (m == M_PAIN) {
            md.sendFinish(md.pain);
        } else if (m == M_WAIT) {
            if (md.hasPhone && !md.active) { md.requestStart(); }
            else { gLink.hello(); }
        } else if (m == M_WARM) {
            md.warmDone();
        } else if (m == M_REST) {
            if (md.rirShow) { md.confirmRir(); }
            else { md.endRest(true); }
        } else if (m == M_TIMED) {
            md.timedPress();
        } else if (m == M_ALLDONE) {
            md.startFinish();
        } else if (m == M_SET) {
            var it = md.cur();
            if (it != null && toInt(it[Q_TIME], 0) > 0) {
                md.timedEnter();
                md.timedStart();
            } else {
                md.doneSet(null);
            }
        }
        Ui.requestUpdate();
        return true;
    }

    function onBack() {
        var md = gModel;
        var m = md.mode();
        if (m == M_SUM) { Sys.exit(); return true; }
        if (m == M_WAIT && !md.active) { return false; }
        if (m == M_SET) {
            md.sel = 1 - md.sel;
        } else if (m == M_REST && md.rirShow) {
            md.skipRir();
        } else if (m == M_TIMED) {
            md.tm = T_NONE;
        } else if (m == M_PAIN) {
            md.painMode = false;
        } else {
            openMenu();
        }
        Ui.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        step(1);
        return true;
    }

    function onNextPage() {
        step(-1);
        return true;
    }

    function step(dir) {
        var md = gModel;
        var m = md.mode();
        if (m == M_SET) {
            md.adjust(dir);
        } else if (m == M_REST) {
            if (md.rirShow) {
                md.rirVal += dir;
                if (md.rirVal < 0) { md.rirVal = 0; }
                if (md.rirVal > 4) { md.rirVal = 4; }
            } else {
                md.addRest(dir * 15);
            }
        } else if (m == M_PAIN) {
            md.pain += dir;
            if (md.pain < 0) { md.pain = 0; }
            if (md.pain > 10) { md.pain = 10; }
        }
        Ui.requestUpdate();
    }

    function onMenu() {
        openMenu();
        return true;
    }

    function openMenu() {
        var md = gModel;
        var menu = new Ui.Menu2({:title => "Treino " + md.wk});
        var m = md.mode();
        if (md.active) {
            if (m == M_SET || m == M_TIMED || m == M_REST) {
                menu.addItem(new Ui.MenuItem("Pular série", null, :skipSet, {}));
                menu.addItem(new Ui.MenuItem("Pular exercício", null, :skipEx, {}));
            }
            menu.addItem(new Ui.MenuItem("Concluir treino", "salva no celular e no Garmin", :finish, {}));
        } else if (md.hasPhone) {
            menu.addItem(new Ui.MenuItem("Iniciar treino " + md.nextKey, null, :start, {}));
        }
        menu.addItem(new Ui.ToggleMenuItem("Aviso FC recuperada", "vibra no descanso", :hrAlert, md.hrAlert, {}));
        menu.addItem(new Ui.ToggleMenuItem("Vibrar 10 s antes", "do fim do descanso", :vib10, md.vib10, {}));
        menu.addItem(new Ui.MenuItem("Sincronizar agora", null, :sync, {}));
        menu.addItem(new Ui.MenuItem("Sair", null, :exit, {}));
        Ui.pushView(menu, new MainMenuDelegate(), Ui.SLIDE_UP);
    }
}

class MainMenuDelegate extends Ui.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var md = gModel;
        var id = item.getId();
        if (id == :hrAlert) {
            md.hrAlert = item.isEnabled();
            md.saveCfg();
            return;
        }
        if (id == :vib10) {
            md.vib10 = item.isEnabled();
            md.saveCfg();
            return;
        }
        if (id == :exit) {
            if (gRec.isOn()) {
                var sub = new Ui.Menu2({:title => "Sair"});
                sub.addItem(new Ui.MenuItem("Salvar e sair", "o treino segue no celular", :saveExit, {}));
                sub.addItem(new Ui.MenuItem("Descartar gravação", "não salva no Garmin", :discardExit, {}));
                sub.addItem(new Ui.MenuItem("Voltar", null, :back, {}));
                Ui.pushView(sub, new ExitMenuDelegate(), Ui.SLIDE_LEFT);
            } else {
                Sys.exit();
            }
            return;
        }
        Ui.popView(Ui.SLIDE_DOWN);
        if (id == :skipSet) { md.skipSet(); }
        else if (id == :skipEx) { md.skipExercise(); }
        else if (id == :finish) { md.startFinish(); }
        else if (id == :start) { md.requestStart(); }
        else if (id == :sync) { gLink.nextTry = 0; gLink.fails = 0; gLink.pump(); gLink.hello(); }
        Ui.requestUpdate();
    }

    function onBack() {
        Ui.popView(Ui.SLIDE_DOWN);
    }
}

class ExitMenuDelegate extends Ui.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :saveExit) {
            gModel.persist();
            gRec.finish(true);
            Sys.exit();
        } else if (id == :discardExit) {
            gModel.persist();
            gRec.finish(false);
            Sys.exit();
        } else {
            Ui.popView(Ui.SLIDE_RIGHT);
        }
    }

    function onBack() {
        Ui.popView(Ui.SLIDE_RIGHT);
    }
}
