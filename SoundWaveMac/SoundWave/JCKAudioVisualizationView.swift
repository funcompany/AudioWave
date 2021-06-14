//
//  JCKAudioVisualizationView.swift
//
//  Created by Bastien Falcou on 12/6/16.
//

import AVFoundation
import Cocoa

public class JCKAudioVisualizationView: NSView {
	public enum AudioVisualizationMode {
		case read
		case write
	}

	private enum LevelBarType {
		case upper
		case lower
		case single
	}

	@IBInspectable public var meteringLevelBarWidth: CGFloat = 3.0 {
		didSet {
            self.setNeedsDisplay(bounds)
		}
	}
	@IBInspectable public var meteringLevelBarInterItem: CGFloat = 2.0 {
		didSet {
			self.setNeedsDisplay(bounds)
		}
	}
	@IBInspectable public var meteringLevelBarCornerRadius: CGFloat = 2.0 {
		didSet {
			self.setNeedsDisplay(bounds)
		}
	}
	@IBInspectable public var meteringLevelBarSingleStick: Bool = false {
		didSet {
			self.setNeedsDisplay(bounds)
		}
	}

    public var sampleRate: Int = 1
    
	public var audioVisualizationMode: AudioVisualizationMode = .read

	public var audioVisualizationTimeInterval: TimeInterval = 0.05 // Time interval between each metering bar representation

	// Specify a `gradientPercentage` to have the width of gradient be that percentage of the view width (starting from left)
	// The rest of the screen will be filled by `self.gradientStartColor` to display nicely.
	// Do not specify any `gradientPercentage` for gradient calculating fitting size automatically.
	public var currentGradientPercentage: Float?

	private var meteringLevelsArray: [Float] = []    // Mutating recording array (values are percentage: 0.0 to 1.0)
	private var meteringLevelsClusteredArray: [Float] = [] // Generated read mode array (values are percentage: 0.0 to 1.0)

	private var currentMeteringLevelsArray: [Float] {
		if !self.meteringLevelsClusteredArray.isEmpty {
			return meteringLevelsClusteredArray
		}
		return meteringLevelsArray
	}

	private var playChronometer: Chronometer?
    private var offsetX: CGFloat = 0
    
	public var meteringLevels: [Float]? {
		didSet {
			if let meteringLevels = self.meteringLevels {
				self.meteringLevelsClusteredArray = meteringLevels
				self.currentGradientPercentage = 0.0
				_ = self.scaleSoundDataToFitScreen()
			}
		}
	}

	static var audioVisualizationDefaultGradientStartColor: NSColor {
		return NSColor(red: 61.0 / 255.0, green: 20.0 / 255.0, blue: 117.0 / 255.0, alpha: 1.0)
	}
	static var audioVisualizationDefaultGradientEndColor: NSColor {
		return NSColor(red: 166.0 / 255.0, green: 150.0 / 255.0, blue: 225.0 / 255.0, alpha: 1.0)
	}

	@IBInspectable public var gradientStartColor: NSColor = JCKAudioVisualizationView.audioVisualizationDefaultGradientStartColor {
		didSet {
			self.setNeedsDisplay(bounds)
		}
	}
	@IBInspectable public var gradientEndColor: NSColor = JCKAudioVisualizationView.audioVisualizationDefaultGradientEndColor {
		didSet {
			self.setNeedsDisplay(bounds)
		}
	}

	override public init(frame: CGRect) {
		super.init(frame: frame)
	}

	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	override public func draw(_ rect: CGRect) {
		super.draw(rect)

		if let context = NSGraphicsContext.current?.cgContext {
			self.drawLevelBarsMaskAndGradient(inContext: context)
		}
	}

	public func reset() {
        self.animationTimer?.invalidate()
        self.animationTimer = nil
        
		self.meteringLevels = nil
		self.currentGradientPercentage = nil
		self.meteringLevelsClusteredArray.removeAll()
		self.meteringLevelsArray.removeAll()
        self.setNeedsDisplay(bounds)
	}

	// MARK: - Record Mode Handling

    public func add(meteringLevel: Float) {
        guard self.audioVisualizationMode == .write else {
            fatalError("trying to populate audio visualization view in read mode")
        }

        self.animationTimer?.invalidate()
        self.animationTimer = nil
        self.offsetX = 0
        
        let dt: TimeInterval
        let now = Date()
        if self.lastAddedTime != nil {
            dt = now.timeIntervalSince(self.lastAddedTime)
        } else {
            dt = 0
        }
        self.lastAddedTime = now
        
        self.meteringLevelsArray.append(meteringLevel)
        
        if sampleRate > 1 {
            self.meteringLevelsClusteredArray.removeAll()

            let remained = self.meteringLevelsArray.count % sampleRate
            for index in 0 ..< self.meteringLevelsArray.count / sampleRate {
                var sum: Float = 0
                for j in 0 ..< sampleRate {
                    sum += self.meteringLevelsArray[index * sampleRate + j]
                }
                self.meteringLevelsClusteredArray.append(sum / Float(sampleRate))
            }
            if remained > 0 {
                var sum: Float = 0
                let index = self.meteringLevelsArray.count / sampleRate * sampleRate
                for j in 0 ..< remained {
                    sum += self.meteringLevelsArray[index + j]
                }
                self.meteringLevelsClusteredArray.append(sum / Float(remained))
            }
        }
        
        self.setNeedsDisplay(bounds)
        
        let offset = max(self.currentMeteringLevelsArray.count - self.maximumNumberBars, 0)
        if offset > 0, dt > 0, (self.meteringLevelsArray.count % self.sampleRate == 0) {
            let moveStepCount: Int = 20
            let moveDistance = (self.meteringLevelBarWidth + self.meteringLevelBarInterItem)
            let moveStep = moveDistance / CGFloat(moveStepCount)
                animationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(dt) * TimeInterval(sampleRate) / TimeInterval(moveStepCount), repeats: true, block: { [weak self] (_) in
                guard let this = self else { return }

                this.offsetX -= moveStep
                this.setNeedsDisplay(this.bounds)

                if this.offsetX <= -moveDistance {
                    this.animationTimer?.invalidate()
                    this.animationTimer = nil
                }
            })
        }
    }

    private var animationTimer: Timer? = nil
    private var lastAddedTime: Date! = nil
    
	public func scaleSoundDataToFitScreen() -> [Float] {
		if self.meteringLevelsArray.isEmpty {
			return []
		}

		self.meteringLevelsClusteredArray.removeAll()
		var lastPosition: Int = 0

		for index in 0..<self.maximumNumberBars {
			let position: Float = Float(index) / Float(self.maximumNumberBars) * Float(self.meteringLevelsArray.count)
			var h: Float = 0.0

			if self.maximumNumberBars > self.meteringLevelsArray.count && floor(position) != position {
				let low: Int = Int(floor(position))
				let high: Int = Int(ceil(position))

				if high < self.meteringLevelsArray.count {
					h = self.meteringLevelsArray[low] + ((position - Float(low)) * (self.meteringLevelsArray[high] - self.meteringLevelsArray[low]))
				} else {
					h = self.meteringLevelsArray[low]
				}
			} else {
				for nestedIndex in lastPosition...Int(position) {
					h += self.meteringLevelsArray[nestedIndex]
				}
				let stepsNumber = Int(1 + position - Float(lastPosition))
				h = h / Float(stepsNumber)
			}

			lastPosition = Int(position)
			self.meteringLevelsClusteredArray.append(h)
		}
		self.setNeedsDisplay(bounds)
		return self.meteringLevelsClusteredArray
	}

	// PRAGMA: - Play Mode Handling

	public func play(from url: URL) {
		guard self.audioVisualizationMode == .read else {
			fatalError("trying to read audio visualization in write mode")
		}

		AudioContext.load(fromAudioURL: url) { audioContext in
			guard let audioContext = audioContext else {
				fatalError("Couldn't create the audioContext")
			}
			self.meteringLevels = audioContext.render(targetSamples: 100)
			self.play(for: 2)
		}
	}

	public func play(for duration: TimeInterval) {
		guard self.audioVisualizationMode == .read else {
			fatalError("trying to read audio visualization in write mode")
		}

		guard self.meteringLevels != nil else {
			fatalError("trying to read audio visualization of non initialized sound record")
		}

		if let currentChronometer = self.playChronometer {
			currentChronometer.start() // resume current
			return
		}

		self.playChronometer = Chronometer(withTimeInterval: self.audioVisualizationTimeInterval)
		self.playChronometer?.start(shouldFire: false)

		self.playChronometer?.timerDidUpdate = { [weak self] timerDuration in
			guard let this = self else {
				return
			}

			if timerDuration >= duration {
				this.stop()
				return
			}

			this.currentGradientPercentage = Float(timerDuration) / Float(duration)
            this.setNeedsDisplay(this.bounds)
		}
	}

	public func pause() {
		guard let chronometer = self.playChronometer, chronometer.isPlaying else {
			fatalError("trying to pause audio visualization view when not playing")
		}
		self.playChronometer?.pause()
	}

	public func stop() {
        self.animationTimer?.invalidate()
        self.animationTimer = nil
        
		self.playChronometer?.stop()
		self.playChronometer = nil

		self.currentGradientPercentage = 1.0
        self.setNeedsDisplay(bounds)
		self.currentGradientPercentage = nil
	}

	// MARK: - Mask + Gradient
    private func makeMask(with size: NSSize) -> NSImage {
        let maskImage = NSImage(size: size)
        let rep = NSBitmapImageRep.init(bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSColorSpaceName.calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0)!
        
        maskImage.addRepresentation(rep)
        maskImage.lockFocus()

        if let context = NSGraphicsContext.current?.cgContext {
            NSColor.black.set()

            drawMeteringLevelBars(inContext: context)
        }

        maskImage.unlockFocus()
        
        return maskImage
    }
    
	private func drawLevelBarsMaskAndGradient(inContext context: CGContext) {
		if self.currentMeteringLevelsArray.isEmpty {
			return
		}

		context.saveGState()

        autoreleasepool {
            let maskImage = makeMask(with: bounds.size)
            context.clip(to: self.bounds, mask: maskImage._cgImage!)
            self.drawGradient(inContext: context)
        }
        
		context.restoreGState()
	}

	private func drawGradient(inContext context: CGContext) {
		if self.currentMeteringLevelsArray.isEmpty {
			return
		}

		context.saveGState()

		let startPoint = CGPoint(x: 0.0, y: self.centerY)
		var endPoint = CGPoint(x: self.xLeftMostBar() + self.meteringLevelBarWidth, y: self.centerY)

		if let gradientPercentage = self.currentGradientPercentage {
			endPoint = CGPoint(x: self.frame.size.width * CGFloat(gradientPercentage), y: self.centerY)
		}

		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let colorLocations: [CGFloat] = [0.0, 1.0]
		let colors = [self.gradientStartColor.cgColor, self.gradientEndColor.cgColor]

		let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: colorLocations)

		context.drawLinearGradient(gradient!, start: startPoint, end: endPoint, options: CGGradientDrawingOptions(rawValue: 0))

		context.restoreGState()

		if self.currentGradientPercentage != nil {
			self.drawPlainBackground(inContext: context, fillFromXCoordinate: endPoint.x)
		}
	}

	private func drawPlainBackground(inContext context: CGContext, fillFromXCoordinate xCoordinate: CGFloat) {
		context.saveGState()

		let squarePath = NSBezierPath()

		squarePath.move(to: NSPoint(x: xCoordinate, y: 0.0))
		squarePath.line(to: NSPoint(x: self.frame.size.width, y: 0.0))
		squarePath.line(to: NSPoint(x: self.frame.size.width, y: self.frame.size.height))
		squarePath.line(to: NSPoint(x: xCoordinate, y: self.frame.size.height))

		squarePath.close()
		squarePath.addClip()

		self.gradientStartColor.setFill()
		squarePath.fill()

		context.restoreGState()
	}

	// MARK: - Bars

	private func drawMeteringLevelBars(inContext context: CGContext) {
		let offset = max(self.currentMeteringLevelsArray.count - self.maximumNumberBars, 0)

		for index in offset..<self.currentMeteringLevelsArray.count {
			if self.meteringLevelBarSingleStick {
				self.drawBar(index - offset, meteringLevelIndex: index, levelBarType: .single, context: context)
			} else {
				self.drawBar(index - offset, meteringLevelIndex: index, levelBarType: .upper, context: context)
				self.drawBar(index - offset, meteringLevelIndex: index, levelBarType: .lower, context: context)
			}
		}
	}

	private func drawBar(_ barIndex: Int, meteringLevelIndex: Int, levelBarType: LevelBarType, context: CGContext) {
		context.saveGState()

		let xPointForMeteringLevel = offsetX + self.xPointForMeteringLevel(barIndex)
        
        var widthForMeteringLevel = self.meteringLevelBarWidth
		var heightForMeteringLevel = self.heightForMeteringLevel(self.currentMeteringLevelsArray[meteringLevelIndex])
        
        let rightX: CGFloat
        if (self.currentMeteringLevelsArray.count > self.maximumNumberBars) {
            rightX = self.xPointForMeteringLevel(self.maximumNumberBars - 1)
        } else {
            rightX = self.xPointForMeteringLevel(self.currentMeteringLevelsArray.count - 1)
        }
        
        let dx = rightX - xPointForMeteringLevel
        let tx = self.frame.size.width / 20
        if dx <= tx {
            let weight = dx / tx
            widthForMeteringLevel *= weight
            heightForMeteringLevel *= weight
        }
        
        if widthForMeteringLevel < 1 {
            widthForMeteringLevel = 1
        }
        if heightForMeteringLevel < 1 {
            heightForMeteringLevel = 1
        }
        
        let barRect: NSRect
		switch levelBarType {
		case .upper:
			barRect = NSRect(x: xPointForMeteringLevel,
							 y: self.centerY - heightForMeteringLevel,
							 width: widthForMeteringLevel,
							 height: heightForMeteringLevel)
		case .lower:
			barRect = NSRect(x: xPointForMeteringLevel,
							 y: self.centerY,
							 width: widthForMeteringLevel,
							 height: heightForMeteringLevel)
		case .single:
			barRect = NSRect(x: xPointForMeteringLevel,
							 y: self.centerY - heightForMeteringLevel,
							 width: widthForMeteringLevel,
							 height: heightForMeteringLevel * 2)
		}

        let barPath = NSBezierPath(roundedRect: barRect, xRadius: meteringLevelBarCornerRadius, yRadius: meteringLevelBarCornerRadius)

		NSColor.black.set()
		barPath.fill()

		context.restoreGState()
	}

	// MARK: - Points Helpers

	private var centerY: CGFloat {
		return self.frame.size.height / 2.0
	}

	private var maximumBarHeight: CGFloat {
		return self.frame.size.height / 2.0
	}

	private var maximumNumberBars: Int {
		return Int(self.frame.size.width / (self.meteringLevelBarWidth + self.meteringLevelBarInterItem))
	}

	private func xLeftMostBar() -> CGFloat {
		return self.xPointForMeteringLevel(min(self.maximumNumberBars - 1, self.currentMeteringLevelsArray.count - 1))
	}

	private func heightForMeteringLevel(_ meteringLevel: Float) -> CGFloat {
		return CGFloat(meteringLevel) * self.maximumBarHeight
	}

	private func xPointForMeteringLevel(_ atIndex: Int) -> CGFloat {
		return CGFloat(atIndex) * (self.meteringLevelBarWidth + self.meteringLevelBarInterItem)
	}
}

fileprivate extension NSImage {
    var _cgImage: CGImage? {
        var imageRect = NSMakeRect(0, 0, self.size.width, self.size.height)
        let cgImage = self.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        return cgImage
    }
}
