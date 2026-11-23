using Toybox.Application as App;
using Toybox.WatchUi as Ui;

var gModel = null;
var gLink = null;
var gRec = null;

class MeuTreinoApp extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        gRec = new Recorder();
        gModel = new Model();
        gLink = new PhoneLink();
        if (gModel.active) { gRec.start("Treino " + gModel.wk); }
        gLink.hello();
        demoHook();
    }

    function onStop(state) {
        if (gModel != null) { gModel.persist(); }
        // saindo no meio do treino: guarda o que foi gravado em vez de perder
        if (gRec != null && gRec.isOn()) { gRec.finish(gRec.sets > 0); }
    }

    function getInitialView() {
        var v = new MainView();
        return [v, new MainDelegate(v)];
    }
}

(:nodemo)
function demoHook() { }
