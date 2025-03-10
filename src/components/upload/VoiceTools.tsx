import React, { useState, useRef } from 'react';
import { Mic, Square, Play, Pause, Trash2 } from 'lucide-react';
import WaveSurfer from 'wavesurfer.js';

interface VoiceToolsProps {
  voiceOver: {
    url: string;
    duration: number;
  } | null;
  onVoiceAdd: (voice: { url: string; duration: number }) => void;
  onVoiceRemove: () => void;
}

export function VoiceTools({
  voiceOver,
  onVoiceAdd,
  onVoiceRemove
}: VoiceToolsProps) {
  const [isRecording, setIsRecording] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);
  const [recordingTime, setRecordingTime] = useState(0);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const timerRef = useRef<number | null>(null);
  const wavesurferRef = useRef<WaveSurfer | null>(null);

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;
      chunksRef.current = [];

      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) {
          chunksRef.current.push(e.data);
        }
      };

      mediaRecorder.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: 'audio/webm' });
        const url = URL.createObjectURL(blob);
        onVoiceAdd({
          url,
          duration: recordingTime
        });
      };

      mediaRecorder.start();
      setIsRecording(true);

      // Start timer
      let time = 0;
      timerRef.current = window.setInterval(() => {
        time += 1;
        setRecordingTime(time);
      }, 1000);
    } catch (err) {
      console.error('Error starting recording:', err);
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      mediaRecorderRef.current.stream.getTracks().forEach(track => track.stop());
      setIsRecording(false);
      if (timerRef.current) {
        clearInterval(timerRef.current);
      }
    }
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const togglePlayback = () => {
    if (wavesurferRef.current) {
      if (isPlaying) {
        wavesurferRef.current.pause();
      } else {
        wavesurferRef.current.play();
      }
      setIsPlaying(!isPlaying);
    }
  };

  React.useEffect(() => {
    if (voiceOver && !wavesurferRef.current) {
      const wavesurfer = WaveSurfer.create({
        container: '#waveform',
        waveColor: '#4B5563',
        progressColor: '#00E5FF',
        cursorColor: '#00E5FF',
        barWidth: 2,
        barRadius: 3,
        cursorWidth: 1,
        height: 50,
        barGap: 3
      });

      wavesurfer.load(voiceOver.url);
      wavesurfer.on('finish', () => setIsPlaying(false));
      wavesurferRef.current = wavesurfer;

      return () => {
        wavesurfer.destroy();
        wavesurferRef.current = null;
      };
    }
  }, [voiceOver]);

  return (
    <div className="p-4 space-y-4">
      {!voiceOver ? (
        <div className="text-center">
          <button
            onClick={isRecording ? stopRecording : startRecording}
            className={`p-4 rounded-full ${
              isRecording
                ? 'bg-red-500 hover:bg-red-600'
                : 'bg-cyan-400 hover:bg-cyan-300'
            } transition-colors`}
          >
            {isRecording ? (
              <Square className="w-6 h-6 text-white" />
            ) : (
              <Mic className="w-6 h-6 text-gray-900" />
            )}
          </button>
          {isRecording && (
            <div className="mt-4 text-red-500 animate-pulse">
              Recording... {formatTime(recordingTime)}
            </div>
          )}
        </div>
      ) : (
        <div className="space-y-4">
          <div id="waveform" />
          <div className="flex items-center justify-between">
            <button
              onClick={togglePlayback}
              className="p-2 bg-cyan-400 text-gray-900 rounded-full hover:bg-cyan-300 transition-colors"
            >
              {isPlaying ? (
                <Pause className="w-5 h-5" />
              ) : (
                <Play className="w-5 h-5" />
              )}
            </button>
            <span className="text-sm text-gray-400">
              {formatTime(Math.floor(voiceOver.duration))}
            </span>
            <button
              onClick={onVoiceRemove}
              className="p-2 text-red-400 hover:text-red-300 transition-colors"
            >
              <Trash2 className="w-5 h-5" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}