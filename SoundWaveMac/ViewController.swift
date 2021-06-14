//
//  ViewController.swift
//  SoundWaveMac
//
//  Created by Dalibor Ristic on 11/6/20.
//

import Cocoa

@available(OSX 10.15, *)
class ViewController: NSViewController {

    
    @IBOutlet weak var audioWaveView: JCKAudioVisualizationView!
    @IBOutlet weak var toggleButton: NSButton!
    @IBOutlet weak var addSameValueSwitch: NSSwitch!
    
    private var timer: Timer? = nil
    private var isRecording: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        audioWaveView.gradientStartColor = NSColor.red
        audioWaveView.gradientEndColor = NSColor.red
        audioWaveView.meteringLevelBarSingleStick = true
        audioWaveView.meteringLevelBarInterItem = 4
    }

    // MARK: - Recording
    func startRecording() {
        stopRecording()
        
        audioWaveView.reset()
        audioWaveView.audioVisualizationMode = .write
        audioWaveView.sampleRate = 1

        let isSame = addSameValueSwitch.state == .on
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: { [weak self] (_) in
            let power:Float = isSame ? 0.1 : Float(Int.random(in: 0 ... 100)) / Float(100)
            self?.audioWaveView.add(meteringLevel: power)
        })
    }
    
    func stopRecording() {
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
        
        audioWaveView.stop()
    }
    
    // MARK: - UI Action
    @IBAction func onToggle(_ sender: Any) {
        if isRecording {
            stopRecording()
            
            isRecording = false
            toggleButton.title = "Start"
            addSameValueSwitch.isEnabled = true
        } else {
            startRecording()
            
            isRecording = true
            toggleButton.title = "Stop"
            addSameValueSwitch.isEnabled = false
        }
    }
}

