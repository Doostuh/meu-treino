using Toybox.ActivityRecording as AR;
using Toybox.FitContributor as Fit;
using Toybox.Lang;

// Grava o treino como atividade "Musculação" no Garmin: FC, calorias,
// uma volta por série (com carga e repetições) e uma volta por descanso.
class Recorder {
    var s = null;
    var fKg = null;
    var fReps = null;
    var fVol = null;
    var fSets = null;
    var vol = 0.0;
    var sets = 0;

    function initialize() { }

    function isOn() { return s != null; }

    function start(name) {
        if (s != null) { return; }
        if (!(Toybox has :ActivityRecording)) { return; }
        try {
            s = AR.createSession({
                :name => name,
                :sport => AR.SPORT_TRAINING,
                :subSport => AR.SUB_SPORT_STRENGTH_TRAINING
            });
            fKg = s.createField("carga", 0, Fit.DATA_TYPE_FLOAT, {:mesgType => Fit.MESG_TYPE_LAP, :units => "kg"});
            fReps = s.createField("reps", 1, Fit.DATA_TYPE_UINT16, {:mesgType => Fit.MESG_TYPE_LAP, :units => "rep"});
            fVol = s.createField("volume", 2, Fit.DATA_TYPE_FLOAT, {:mesgType => Fit.MESG_TYPE_SESSION, :units => "kg"});
            fSets = s.createField("series", 3, Fit.DATA_TYPE_UINT16, {:mesgType => Fit.MESG_TYPE_SESSION, :units => "x"});
            s.start();
            vol = 0.0;
            sets = 0;
        } catch (e) {
            s = null;
        }
    }

    function setLap(kg100, reps) {
        sets += 1;
        vol += kg100 * reps / 100.0;
        if (s == null) { return; }
        try {
            fKg.setData(kg100 / 100.0);
            fReps.setData(reps);
            fVol.setData(vol.toFloat());
            fSets.setData(sets);
            s.addLap();
            fKg.setData(0.0);
            fReps.setData(0);
        } catch (e) { }
    }

    function restLap() {
        if (s == null) { return; }
        try {
            if (s.isRecording()) { s.addLap(); }
        } catch (e) { }
    }

    function finish(save) {
        if (s == null) { return; }
        try {
            if (s.isRecording()) { s.stop(); }
            if (save) { s.save(); } else { s.discard(); }
        } catch (e) { }
        s = null;
    }
}
