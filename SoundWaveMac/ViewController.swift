//
//  ViewController.swift
//  SoundWaveMac
//
//  Created by Dalibor Ristic on 11/6/20.
//

import Cocoa

class ViewController: NSViewController {

    
    @IBOutlet weak var audioWaveView: JCKAudioVisualizationView!
    @IBOutlet weak var toggleButton: NSButton!
    
    private var timer: Timer? = nil
    private var duration: TimeInterval = 0
    private var isRecording: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        audioWaveView.audioVisualizationTimeInterval = 0.1
    }

    // MARK: - Recording
    func startRecording() {
        stopRecording()
        
        audioWaveView.reset()
        audioWaveView.audioVisualizationMode = .write
        
        duration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] (_) in
            let power = Float(Int.random(in: 0 ... 100)) / Float(100)
            self?.audioWaveView.add(meteringLevel: power)
            
            self?.duration += 0.1
        })
    }
    
    func stopRecording() {
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
    }
    
    // MARK: - UI Action
    @IBAction func onToggle(_ sender: Any) {
        if isRecording {
            stopRecording()
            
            isRecording = false
            toggleButton.title = "Start"
        } else {
            startRecording()
            
            isRecording = true
            toggleButton.title = "Stop"
        }
    }
}

