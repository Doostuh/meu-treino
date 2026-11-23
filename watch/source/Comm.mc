using Toybox.Communications as Comm;
using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
using Toybox.Lang;

// Fila de mensagens para o celular: envia uma de cada vez, guarda se o celular
// estiver fora de alcance e reenvia sozinho quando a conexão volta.
class PhoneLink {
    var outbox = [];
    var busy = false;
    var fails = 0;
    var nextTry = 0;
    var lastOk = 0;
    var lastHi = 0;
    var needHi = false;
    var off = false;
    var seq = 0;
    var sent = [];
    var lastAckAt = 0;
    var lastResend = 0;

    function initialize() {
        var ob = App.Storage.getValue("ob");
        if (ob instanceof Lang.Array) { outbox = ob; }
        var sn = App.Storage.getValue("sn");
        if (sn instanceof Lang.Array) { sent = sn; }
        seq = toInt(App.Storage.getValue("seq"), 0);
        try {
            Comm.registerForPhoneAppMessages(method(:onPhone));
        } catch (e) { }
    }

    function onPhone(msg) {
        var d = msg.data;
        if (d instanceof Lang.Dictionary) {
            var t = d["t"];
            if (t != null && t.equals("s")) {
                ack(d["ak"]);
                gModel.applyState(d, outbox.size() == 0 && sent.size() == 0);
                if (outbox.size() > 0) { needHi = true; }
            }
        }
        Ui.requestUpdate();
    }

    // o celular confirma até qual ação já aplicou; o que não foi confirmado é reenviado
    function ack(ak) {
        var t = Sys.getTimer();
        if (ak == null) { sent = []; save(); return; }
        var a = toInt(ak, 0);
        lastAckAt = t;
        var keep = [];
        for (var i = 0; i < sent.size(); i++) {
            if (toInt(sent[i]["id"], 0) > a) { keep.add(sent[i]); }
        }
        sent = keep;
        if (sent.size() > 0 && t - lastResend > 15000) { resend(); }
        save();
    }

    function resend() {
        lastResend = Sys.getTimer();
        var n = [];
        for (var i = 0; i < sent.size(); i++) { n.add(sent[i]); }
        for (var j = 0; j < outbox.size(); j++) { n.add(outbox[j]); }
        outbox = n;
        sent = [];
        save();
        pump();
    }

    function send(m) {
        seq += 1;
        m["id"] = seq;
        m["_t"] = Sys.getTimer();
        outbox.add(m);
        if (outbox.size() > 60) { outbox = outbox.slice(outbox.size() - 60, outbox.size()); }
        save();
        pump();
    }

    function hello() {
        if (off) { return; }
        lastHi = Sys.getTimer();
        if (outbox.size() == 0 && !busy) {
            busy = true;
            try {
                Comm.transmit({"t" => "hi"}, null, new LinkListener(self, false));
            } catch (e) {
                busy = false;
            }
        }
    }

    function pump() {
        if (off) { outbox = []; return; }
        if (busy || outbox.size() == 0) { return; }
        if (Sys.getTimer() < nextTry) { return; }
        busy = true;
        var m = outbox[0];
        var t0 = toInt(m["_t"], 0);
        var ago = (Sys.getTimer() - t0) / 1000;
        m["ago"] = ago > 0 && t0 > 0 ? ago : 0;
        try {
            Comm.transmit(m, null, new LinkListener(self, true));
        } catch (e) {
            busy = false;
            onFail();
        }
    }

    function onOk(real) {
        busy = false;
        fails = 0;
        nextTry = 0;
        lastOk = Sys.getTimer();
        if (real && outbox.size() > 0) {
            sent.add(outbox[0]);
            if (sent.size() > 80) { sent = sent.slice(sent.size() - 80, sent.size()); }
            outbox = outbox.slice(1, outbox.size());
            save();
        }
        if (outbox.size() > 0) {
            pump();
        } else if (needHi) {
            needHi = false;
            hello();
        }
    }

    function onFail() {
        busy = false;
        fails += 1;
        var wait = fails * 3000;
        if (wait > 30000) { wait = 30000; }
        nextTry = Sys.getTimer() + wait;
        Ui.requestUpdate();
    }

    // chamado a cada segundo pela tela
    function tick() {
        var t = Sys.getTimer();
        if (outbox.size() == 0 && sent.size() > 0 && t - lastAckAt > 45000 && t - lastResend > 45000) {
            resend();
            return;
        }
        if (outbox.size() > 0) {
            pump();
        } else if (!busy && (!gModel.hasPhone && t - lastHi > 8000 || t - gModel.lastPhone > 60000 && t - lastHi > 30000)) {
            hello();
        }
    }

    // 0 = ok, 1 = enviando/pendente, 2 = sem celular
    function status() {
        if (outbox.size() > 0 || sent.size() > 0) { return fails > 1 ? 2 : 1; }
        if (fails > 1) { return 2; }
        if (gModel.hasPhone || lastOk > 0) { return 0; }
        return 1;
    }

    function save() {
        try {
            App.Storage.setValue("ob", outbox);
            App.Storage.setValue("sn", sent);
            App.Storage.setValue("seq", seq);
        } catch (e) { }
    }
}

class LinkListener extends Comm.ConnectionListener {
    var link;
    var real;

    function initialize(l, r) {
        ConnectionListener.initialize();
        link = l;
        real = r;
    }

    function onComplete() {
        link.onOk(real);
    }

    function onError() {
        link.onFail();
    }
}
