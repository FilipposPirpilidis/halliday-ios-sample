
//
//  OpusDecoderWrapper.c
//  Core
//
//
#include "include/opus/OpusDecoderWrapper.h"
#include <opus/opus.h>
#include <stdlib.h>

typedef struct {
    OpusDecoder* dec;
    int sampleRate;
    int channels;
} OpusDecoderHandle;

void* opus_decoder_handle_create(int sampleRate, int channels) {
    int err = 0;
    OpusDecoder* dec = opus_decoder_create(sampleRate, channels, &err);
    if (err != OPUS_OK || dec == NULL) return NULL;

    OpusDecoderHandle* h = (OpusDecoderHandle*)calloc(1, sizeof(OpusDecoderHandle));
    if (!h) { opus_decoder_destroy(dec); return NULL; }

    h->dec = dec;
    h->sampleRate = sampleRate;
    h->channels = channels;
    return (void*)h;
}

int opus_decoder_handle_decode_float(void* vh,
                                    const uint8_t* data,
                                    int dataLen,
                                    float* pcmOut,
                                    int maxFrameSize,
                                    int decodeFEC) {
    if (!vh || !pcmOut) return OPUS_BAD_ARG;
    OpusDecoderHandle* h = (OpusDecoderHandle*)vh;
    return opus_decode_float(h->dec, data, dataLen, pcmOut, maxFrameSize, decodeFEC);
}

int opus_decoder_handle_plc_float(void* vh,
                                 float* pcmOut,
                                 int frameSize) {
    if (!vh || !pcmOut) return OPUS_BAD_ARG;
    OpusDecoderHandle* h = (OpusDecoderHandle*)vh;
    return opus_decode_float(h->dec, NULL, 0, pcmOut, frameSize, 0);
}

void opus_decoder_handle_destroy(void* vh) {
    if (!vh) return;
    OpusDecoderHandle* h = (OpusDecoderHandle*)vh;
    if (h->dec) opus_decoder_destroy(h->dec);
    free(h);
}
