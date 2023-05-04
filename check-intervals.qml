import MuseScore 3.0
import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.3
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.1

MuseScore {
	menuPath: "Plugins.Proof Reading.Check Intervals"
	version: "1.1"
	description: "Check melodic & harmonic intervals"
	requiresScore: true
	
	id: checkIntervals
	
	Component.onCompleted: {
		if (mscoreMajorVersion >= 4) {
			checkIntervals.title = "Check for Counterpoint Intervals";
			checkIntervals.categoryCode = "composing-arranging-tools";
		}
	}
	
	onRun: {
		if (!curScore) {
			error("No score open.\nThis plugin requires an open score to run.\n");
		}
		else applyIntervals();
	}
	
	function applyIntervals() {
		var selection = getSelection();
		if (!selection) {
			error("No selection.\nThis plugin requires a current selection to run.\n");
		}
		else {			
			curScore.startCmd();
			clear(selection.startTick);
			check(selection);
			curScore.endCmd();	
		}
	}
	
	function clear(tick) {
		if (curScore) {
			if (curScore.selection && curScore.selection.elements) {
				for (var eCount = 0; eCount < curScore.selection.elements.length; eCount++) {
					if ((curScore.selection.elements[eCount].type === Element.FINGERING || curScore.selection.elements[eCount].type === Element.SYSTEM_TEXT || curScore.selection.elements[eCount].type === Element.STAFF_TEXT) && curScore.selection.elements[eCount].parent.parent.parent.tick != tick)
						removeElement(curScore.selection.elements[eCount]);
				}
			}
		}
	}
	
	function check(selection) {		
		selection.cursor.rewind(1);
		var notes = new Array(selection.endTrack);
		for (var track = selection.startTrack; track < selection.endTrack; track++) notes[track] = null;
		var segment = selection.cursor.segment;
		while (segment && segment.tick < selection.endTick) {			
			var thisTrack = null;
			for (var track = selection.startTrack; track < selection.endTrack; track++) {
				var element = segment.elementAt(track);
				if (element) {
					if (element.type === Element.CHORD) {
						if (notes[track] != null) {
							var text = newElement(Element.FINGERING);
							text.visible = false;
							text.text = returnInterval(notes[track], element.notes[0], 0);
							if (text.text[0] === '<') text.visible = true;
							selection.cursor.track = track;
							selection.cursor.rewindToTick(segment.tick);
							selection.cursor.add(text);
						}
						notes[track] = element.notes[0];
						thisTrack = track;
					}
					else if (element.type === Element.REST) {
						notes[track] = null;
						thisTrack = track;
					}
				}
			}
			var firstBass = true;
			var has5 = false;
			var has6 = false;
			for (var track1 = selection.endTrack; track1 > selection.startTrack; track1--){
				if (notes[track1] != null) {
					var text = newElement(Element.SYSTEM_TEXT);
					for (var track2 = track1 - 1; track2 >= selection.startTrack; track2--) {
						if (notes[track2] != null) {
							var toAdd = returnInterval(notes[track1], notes[track2], 1);
							if (toAdd[0] === '<') text.color = "red";
							if (toAdd[toAdd.length - 1] === '5') has5 = true;
							if (toAdd[toAdd.length - 1] === '6') has6 = true;
							text.text = toAdd + "\n" + text.text;
						}
					}
					if (text.text != "") {
						if (has5 && has6) text.color = "red";
						if (!firstBass) text.visible = false;
						selection.cursor.track = thisTrack;
						selection.cursor.rewindToTick(segment.tick);
						selection.cursor.add(text);			
					}
					firstBass = false;			
				}
			}			
			while (segment.next.tick == segment.next.next.tick) segment = segment.next;
			segment = segment.next;
		}
	}
	
	function returnInterval(note1, note2, mode) {
		if (note2.pitch > note1.pitch) {
			var interval = note2.tpc - note1.tpc;
			if (interval < -8 || interval > 12) return "!";
			var output = intMap[interval + 8];
		}
		else {
			if (note2.pitch == note1.pitch && note2.tpc == note1.tpc) return "U";
			var interval = note1.tpc - note2.tpc;
			if (interval < -8 || interval > 12) return "!";
			var output = "-" + intMap[interval + 8];			
		}
		if (mode === 0) {
			if (!(output === "U" || output === "P8" || output === "-P8" || output === "m2" || output === "M2" || output === "-m2" || output === "-M2" || output === "m3" || output === "M3" || output === "-m3" || output === "-M3" || output === "P4" || output === "-P4" || output === "P5" || output === "-P5" || output === "m6"))
				output = "<b>" + output + "</b>";
		}
		if (mode === 1) {
			if (!(output === "U" || output === "P8" || output === "-P8" || output === "P5" || output === "-P5" || output === "m3" || output === "M3" || output === "-m3" || output === "-M3" || output === "m6" || output === "M6" || output === "-m6" || output === "-M6"))
				output = "<b>" + output + "</b>";
		}
		return output;
	}
	
	property var intMap: ["d4", "d1", "d5", "m2", "m6", "m3", "m7", "P4", "P8", "P5", "M2", "M6", "M3", "M7", "A4", "A1", "A5", "A2", "A6", "A3", "A7"];

	function getSelection() {
		var cursor = curScore.newCursor();
		cursor.rewind(1);
		if (!cursor.segment) return null;
		var selection = {
			cursor: cursor,
			startTick: cursor.segment.parent.firstSegment.tick,
			endTick: null,
			startStaff: 0,
			endStaff: curScore.nstaves,
			startTrack: null,
			endTrack: null
		}
		cursor.rewind(2);
		if (cursor.tick == 0) selection.endTick = curScore.lastSegment.tick + 1;
		else selection.endTick = cursor.tick;
		selection.startTrack = selection.startStaff * 4;
		selection.endTrack = selection.endStaff * 4;
		curScore.startCmd();
		curScore.selection.selectRange(selection.startTick, selection.endTick, selection.startStaff, selection.endStaff);
		curScore.endCmd();
		return selection;
	}
	
	function error(errorMessage) {
		errorDialog.text = qsTr(errorMessage);
        	errorDialog.open();
	}
    	
	MessageDialog {
        	id: errorDialog;
        	title: "Error";
        	text: "";
        	onAccepted: errorDialog.close();
        	visible: false;
    	}
}
