
//
//  OpusDecoderWrapper.h
//  Core
//
//
#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void* opus_decoder_handle_create(int sampleRate, int channels);

int opus_decoder_handle_decode_float(void* h,
                                    const uint8_t* data,
                                    int dataLen,
                                    float* pcmOut,
                                    int maxFrameSize,
                                    int decodeFEC);

int opus_decoder_handle_plc_float(void* h,
                                 float* pcmOut,
                                 int frameSize);

void opus_decoder_handle_destroy(void* h);

#ifdef __cplusplus
}
#endif
