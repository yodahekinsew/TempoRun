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
    
    func getBPM(using signal: [(x: Float, y: Float, z: Float)]) {
        let imuData = signal.map{$0.y} //Get only y-direction IMU data for FFT
        print(imuData)
        let foundFrequences = doFFT(using: imuData)
        print(foundFrequences)
    }
    
    func doFFT(using signal: [Float]) -> [Int] {
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
        
        let componentFrequencies = forwardOutputImag.enumerated().filter {
            $0.element < -1
        }.map {
            return $0.offset
        }
                
        // Prints "[1, 5, 25, 30, 75, 100, 300, 500, 512, 1023]"
        print(componentFrequencies)
        return componentFrequencies
    }
    
    func fftAnalyzer(frameOfSamples: [Float]) -> [Float] {
        // frameOfSamples = [1.0, 2.0, 3.0, 4.0]

        let frameCount = frameOfSamples.count

        let reals = UnsafeMutableBufferPointer<Float>.allocate(capacity: frameCount)
        defer {reals.deallocate()}
        let imags =  UnsafeMutableBufferPointer<Float>.allocate(capacity: frameCount)
        defer {imags.deallocate()}
        _ = reals.initialize(from: frameOfSamples)
        imags.initialize(repeating: 0.0)
        var complexBuffer = DSPSplitComplex(realp: reals.baseAddress!, imagp: imags.baseAddress!)

        let log2Size = Int(log2(Float(frameCount)))
        print(log2Size)

        guard let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2Size), FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer {vDSP_destroy_fftsetup(fftSetup)}

        // Perform a forward FFT
        vDSP_fft_zip(fftSetup, &complexBuffer, 1, vDSP_Length(log2Size), FFTDirection(FFT_FORWARD))

        let realFloats = Array(reals)
        let imaginaryFloats = Array(imags)

        print(realFloats)
        print(imaginaryFloats)

        return realFloats
    }
}
