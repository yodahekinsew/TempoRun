//
//  StepDetector.swift
//  TempoRun
//
//  Created by Yodahe Alemu on 4/25/20.
//  Copyright © 2020 Yodahe Alemu. All rights reserved.
//

import Foundation
import Accelerate

class StepDetector: NSObject {
    
    private var bpmOverTimeX : [Float] = []
    private var bpmOverTimeY : [Float] = []
    private var bpmOverTimeZ : [Float] = []
    
    func testFFT() -> Void {
        let n = vDSP_Length(2048)

        let frequencies: [Float] = [1, 5, 25, 30, 75, 100,
                                    300, 500, 512, 1023]

        let tau: Float = .pi * 2
        let signal: [Float] = (0 ... n).map { index in
            frequencies.reduce(0) { accumulator, frequency in
                let normalizedIndex = Float(index) / Float(n)
                return accumulator + sin(normalizedIndex * frequency * tau)
            }
        }
        print(signal)
        let foundFrequencies = doFFT(using: signal)
        print(foundFrequencies)
    }
    
    func getBPM(using signal: [(x: Float, y: Float, z: Float)]) -> Float {
        let imuDataZ = signal.map{$0.z} //Get only y-direction IMU data for FFT
        var maxFrequencyZ: Float = 0.0
        var maxOffsetZ = 0
        let frequenciesZ = doFFT(using: imuDataZ)
        for i in 0 ..< frequenciesZ.count {
            let frequency = frequenciesZ[i]
            if (frequency.element < maxFrequencyZ && frequency.offset > 1/50*frequenciesZ.count) {
                maxFrequencyZ = frequency.element
                maxOffsetZ = frequency.offset
            }
        }
        if (bpmOverTimeZ.count == 500) {
            bpmOverTimeZ.removeFirst(1)
        }
        bpmOverTimeZ.append(Float(maxOffsetZ)*50.0/Float(frequenciesZ.count))
        let bpmZ = bpmOverTimeZ.reduce(0.0, +)*60.0/Float(bpmOverTimeY.count)
        
        let imuDataY = signal.map{$0.y} //Get only y-direction IMU data for FFT
        var maxFrequencyY: Float = 0.0
        var maxOffsetY = 0
        let frequenciesY = doFFT(using: imuDataY)
        for i in 0 ..< frequenciesY.count {
            let frequency = frequenciesY[i]
            if (frequency.element < maxFrequencyY && frequency.offset > 1/50*frequenciesY.count) {
                maxFrequencyY = frequency.element
                maxOffsetY = frequency.offset
            }
        }
        if (bpmOverTimeY.count == 500) {
            bpmOverTimeY.removeFirst(1)
        }
        bpmOverTimeY.append(Float(maxOffsetY)*50.0/Float(frequenciesY.count))
        let bpmY = bpmOverTimeY.reduce(0.0, +)*60.0/Float(bpmOverTimeY.count)
        
        let imuDataX = signal.map{$0.x} //Get only y-direction IMU data for FFT
        var maxFrequencyX: Float = 0.0
        var maxOffsetX = 0
        let frequenciesX = doFFT(using: imuDataX)
        for i in 0 ..< frequenciesX.count {
            let frequency = frequenciesX[i]
            if (frequency.element < maxFrequencyX && frequency.offset > 1/50*frequenciesX.count) {
                maxFrequencyX = frequency.element
                maxOffsetX = frequency.offset
            }
        }
        if (bpmOverTimeX.count == 500) {
            bpmOverTimeX.removeFirst(1)
        }
        bpmOverTimeX.append(Float(maxOffsetX)*50.0/Float(frequenciesX.count))
        let bpmX = bpmOverTimeX.reduce(0.0, +)*60.0/Float(bpmOverTimeX.count)
        
//        print("X: \(bpmX), Y: \(bpmY), Z: \(bpmZ)")
        return bpmY
//        print(foundFrequences)
//        let frequencies = fftAnalyzer(frameOfSamples: imuData)
//        let sampling_rate = 50
//        let n = frequencies.count
//        var foundFrequencies: [(index: Int, frequency: Float, value: Float)] = []
//        for i in 0 ..< frequencies.count {
//            let frequency = frequencies[i]
//            if (frequency > 1)
//            {
//                foundFrequencies.append((i, Float(i*sampling_rate/2)/Float(n), frequency))
//            }
//        }
//        print(foundFrequencies)
    }
    
    func doFFT(using signal: [Float]) -> [(offset: Int, element: Float)] {
        let log2n = vDSP_Length(log2(Float(signal.count)))
        guard let fftSetUp = vDSP.FFT(log2n: log2n,
                                      radix: .radix2,
                                      ofType: DSPSplitComplex.self) else {
                                        fatalError("Can't create FFT Setup.")
        }
        
        let halfN = Int(signal.count / 2)
        var forwardInputReal = [Float](repeating: 0, count: halfN)
        var forwardInputImag = [Float](repeating: 0, count: halfN)
        var forwardOutputReal = [Float](repeating: 0, count: halfN)
        var forwardOutputImag = [Float](repeating: 0, count: halfN)
        
        forwardInputReal.withUnsafeMutableBufferPointer { forwardInputRealPtr in
            forwardInputImag.withUnsafeMutableBufferPointer { forwardInputImagPtr in
                forwardOutputReal.withUnsafeMutableBufferPointer { forwardOutputRealPtr in
                    forwardOutputImag.withUnsafeMutableBufferPointer { forwardOutputImagPtr in
                        
                        // 1: Create a `DSPSplitComplex` to contain the signal.
                        var forwardInput = DSPSplitComplex(realp: forwardInputRealPtr.baseAddress!,
                                                           imagp: forwardInputImagPtr.baseAddress!)
                        
                        // 2: Convert the real values in `signal` to complex numbers.
                        signal.withUnsafeBytes {
                            vDSP.convert(interleavedComplexVector: [DSPComplex]($0.bindMemory(to: DSPComplex.self)),
                                         toSplitComplexVector: &forwardInput)
                        }
                        
                        // 3: Create a `DSPSplitComplex` to receive the FFT result.
                        var forwardOutput = DSPSplitComplex(realp: forwardOutputRealPtr.baseAddress!,
                                                            imagp: forwardOutputImagPtr.baseAddress!)
                        
                        // 4: Perform the forward FFT.
                        fftSetUp.forward(input: forwardInput,
                                         output: &forwardOutput)
                    }
                }
            }
        }
        
        let componentFrequencies = forwardOutputImag.enumerated().map{return $0}
//        .filter {
//            $0.element < -1
//        }
//        .map {
//            return $0.offset
//        }
            
        return componentFrequencies
    }
}
