import Quickshell // for PanelWindow
import QtQuick // for Text
import Quickshell.Io // for Process

Variants {
  model: Quickshell.screens;

  delegate: Component {
    PanelWindow {
    // the screen from the screens list will be injected into this
    // property
    property var modelData

    // we can then set the window's screen to the injected property
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 30
    
        ClockWidget {
            anchors.centerIn: parent
        }
    
    }
  }
}
