pragma Singleton
pragma ComponentBehavior: Bound

import "root:/modules/common"
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
	property double memoryTotal: 1
	property double memoryFree: 1
	property double memoryUsed: memoryTotal - memoryFree
    property double memoryUsedPercentage: memoryUsed / memoryTotal
    property double swapTotal: 1
	property double swapFree: 1
	property double swapUsed: swapTotal - swapFree
    property double swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property double cpuUsage: 0
    property var previousCpuStats
    property double mouseBatteryPercentage: 0
    property bool mouseBatteryCharging: false

	Timer {
		interval: 1
        running: true 
        repeat: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }

    // Mouse battery monitor
    Process {
        id: mouseBatteryProcess
        command: ["rivalcfg", "--battery-level"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                console.log("Mouse battery output:", data); // Debug line
                
                // Extract percentage from output like "Discharging [===       ] 35 %" or "Charging [===       ] 35 %"
                const match = data.match(/(\d+)\s*%/);
                if (match) {
                    mouseBatteryPercentage = parseInt(match[1]) / 100.0;
                }
                
                // Check if charging - be more specific about the detection
                const lowerData = data.toLowerCase().trim();
                mouseBatteryCharging = lowerData.startsWith('charging');
                
                console.log("Charging status:", mouseBatteryCharging); // Debug line
            }
        }
        onExited: {
            // Restart after 30 seconds to get updated battery level
            mouseBatteryTimer.start();
        }
    }

    Timer {
        id: mouseBatteryTimer
        interval: 300 // 30 seconds
        onTriggered: {
            mouseBatteryProcess.running = false;
            mouseBatteryProcess.running = true;
        }
    }
}
