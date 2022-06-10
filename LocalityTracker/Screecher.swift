//
//  Screecher.swift
//
//  Created by Jack Bowden on 7/7/21.
//

import Foundation
import AVFoundation

class Screecher: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    
    var engine = AVAudioEngine()
    var player = AVAudioPlayerNode()
    var eqEffect = AVAudioUnitEQ()
    var converter = AVAudioConverter(from: AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: 22050, channels: 1, interleaved: false)!, to: AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: 22050, channels: 1, interleaved: false)!)
    let synthesizer = AVSpeechSynthesizer()
    var bufferCounter: Int = 0
    let audioSession = AVAudioSession.sharedInstance()
    let outputFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: 22050, channels: 1, interleaved: false)!
    
    var pendingSpeakingNotifications:[String] = []

    init(vocal: Bool) {
        super.init()
        setupAudio(format: outputFormat, globalGain: 0)
    }
    
    func shutup() {
        if self.player.isPlaying {
            self.player.stop()
            self.bufferCounter = 0
        }
        if self.synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func play(enteredstring: String, alert: Bool = false, interupt: Bool? = false) {
        //let path = Bundle.main.path(forResource: "sounds/awacslouder", ofType: "mp3")!
        //let file = try! AVAudioFile(forReading: URL(fileURLWithPath: path))
        //self.player.scheduleFile(file, at: nil, completionHandler: nil)
        //let utterance = AVSpeechUtterance(string: "This is to test if iOS is able to boost the voice output above the 100% limit.")

        eqEffect.globalGain = UserDefaults.standard.float(forKey: "alert_sound_value") //8-10 last one was 15 on 21-apr-2021 //was 12 on 10-march-2022
        
        if UserDefaults.standard.bool(forKey: "mute_preference") {
            return
        }
        
        if (alert == true || interupt == true) {
            shutup()
        }
        
        if (alert == true && !UserDefaults.standard.bool(forKey: "screecher_alert_sound")) {
            var file = try! AVAudioFile(forReading: URL(fileURLWithPath: Bundle.main.path(forResource: "sounds/crystal", ofType: "mp3")!)) //awacs7onehalfdblouder
            if !UserDefaults.standard.bool(forKey: "use_alternative_sound") {
                file = try! AVAudioFile(forReading: URL(fileURLWithPath: Bundle.main.path(forResource: "sounds/awacsnormal", ofType: "mp3")!)) //awacs7onehalfdblouder
            }
            self.player.scheduleFile(file, at: nil, completionHandler: nil)
        }
        
        let utterance = AVSpeechUtterance(string: enteredstring)
        
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.siri_female_en-US_compact")
        utterance.postUtteranceDelay = 0.0 //0.025 0.010 0.005
        //utterance.preUtteranceDelay = 0.99 //0.025 0.010 0.005
        utterance.pitchMultiplier = 1.05 //1.05 or 1.03 0.95
        //utterance.prefersAssistiveTechnologySettings = true
        utterance.rate = (AVSpeechUtteranceMaximumSpeechRate-AVSpeechUtteranceMinimumSpeechRate/2) * 0.51 //0.47
                
        synthesizer.write(utterance) { buffer in
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer, pcmBuffer.frameLength > 0 else {
                //print("Could not create buffer or buffer empty")
                return
            }

            // QUIRCK Need to convert the buffer to different format because AVAudioEngine does not support the format returned from AVSpeechSynthesizer
            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: pcmBuffer.format.sampleRate, channels: pcmBuffer.format.channelCount, interleaved: false)!, frameCapacity: pcmBuffer.frameCapacity)!
            do {
                try self.converter!.convert(to: convertedBuffer, from: pcmBuffer)
                self.bufferCounter += 1
                self.player.scheduleBuffer(convertedBuffer, completionCallbackType: .dataPlayedBack, completionHandler: { (type) -> Void in
                    DispatchQueue.main.async {
                        self.bufferCounter -= 1
                    //    if self.bufferCounter == 0 {
                    //        self.player.stop()
                    //        self.engine.stop()
                    //        try? self.audioSession.setActive(false, options: [])
                    //    }
                    }

                })

                self.converter!.reset()
                //self.player.prepare(withFrameCount: convertedBuffer.frameLength)
            }
            catch let error {
                print(error.localizedDescription)
            }
        }

        activateAudioSession()

        if !self.engine.isRunning {
            try! self.engine.start()
        }
        if !self.player.isPlaying {
            self.player.play()
        }
        
    //    if (!pendingSpeakingNotifications.isEmpty) {
    //        processSpeakingNotificationQueue()
    //    }
    }
    
    func setupAudio(format: AVAudioFormat, globalGain: Float) {
        // QUIRCK: Connecting the equalizer to the engine somehow starts the shared audioSession, and if that audiosession is not configured with .mixWithOthers and if it's not deactivated afterwards, this will stop any background music that was already playing. So first configure the audio session, then setup the engine and then deactivate the session again.
        try? self.audioSession.setCategory(.playback, options: .mixWithOthers)

        eqEffect.globalGain = globalGain
        engine.attach(player)
        engine.attach(eqEffect)
        engine.connect(player, to: eqEffect, format: format)
        engine.connect(eqEffect, to: engine.mainMixerNode, format: format)
        engine.prepare()

        try? self.audioSession.setActive(false)
    }

    func activateAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .voicePrompt, options: [.mixWithOthers])//, .duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("An error has occurred while setting the AVAudioSession.")
        }
    }
}
