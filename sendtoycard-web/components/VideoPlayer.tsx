'use client'

import { useRef, useState, useEffect } from 'react'

interface VideoPlayerProps {
  videoUrl: string
  recipientName: string
}

/**
 * Video player component with auto-play, TOY branding overlay, and unmute control.
 *
 * Features:
 * - Auto-plays muted (required for mobile Safari)
 * - Plays inline (no fullscreen takeover on mobile)
 * - Loops continuously
 * - Subtle "Made with TOY" branding (bottom right)
 * - Unmute button toggle (bottom left)
 * - Responsive sizing with max-w-2xl constraint
 */
export function VideoPlayer({ videoUrl, recipientName }: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [isMuted, setIsMuted] = useState(true)
  const [hasError, setHasError] = useState(false)
  const [isLoading, setIsLoading] = useState(true)

  // Handle video load events
  useEffect(() => {
    const video = videoRef.current
    if (!video) return

    const handleCanPlay = () => setIsLoading(false)
    const handleError = () => {
      setHasError(true)
      setIsLoading(false)
    }

    video.addEventListener('canplay', handleCanPlay)
    video.addEventListener('error', handleError)

    return () => {
      video.removeEventListener('canplay', handleCanPlay)
      video.removeEventListener('error', handleError)
    }
  }, [])

  // Toggle mute state
  const toggleMute = () => {
    const video = videoRef.current
    if (video) {
      video.muted = !video.muted
      setIsMuted(video.muted)
    }
  }

  if (hasError) {
    return (
      <div className="mx-auto max-w-2xl">
        <div className="aspect-video rounded-lg bg-toy-surface flex items-center justify-center shadow-xl">
          <div className="text-center p-8">
            <svg
              className="mx-auto h-16 w-16 text-toy-text-secondary opacity-50 mb-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={1.5}
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z"
              />
            </svg>
            <p className="text-toy-text-secondary">
              Unable to load video. Please try refreshing the page.
            </p>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-2xl">
      <div className="relative rounded-lg overflow-hidden shadow-xl bg-black">
        {/* Loading state */}
        {isLoading && (
          <div className="absolute inset-0 flex items-center justify-center bg-toy-surface z-10">
            <div className="animate-pulse">
              <svg
                className="h-12 w-12 text-toy-primary"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={1.5}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 0 1 0 1.972l-11.54 6.347a1.125 1.125 0 0 1-1.667-.986V5.653Z"
                />
              </svg>
            </div>
          </div>
        )}

        {/* Video element */}
        <video
          ref={videoRef}
          src={videoUrl}
          autoPlay
          muted
          playsInline
          loop
          className="w-full aspect-video"
        />

        {/* Unmute button - bottom left */}
        <button
          onClick={toggleMute}
          className="absolute bottom-4 left-4 p-2 rounded-full bg-black/50 hover:bg-black/70 transition-colors"
          aria-label={isMuted ? 'Unmute video' : 'Mute video'}
        >
          {isMuted ? (
            // Speaker muted icon
            <svg
              className="h-6 w-6 text-white"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={1.5}
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M17.25 9.75 19.5 12m0 0 2.25 2.25M19.5 12l2.25-2.25M19.5 12l-2.25 2.25m-10.5-6 4.72-4.72a.75.75 0 0 1 1.28.53v15.88a.75.75 0 0 1-1.28.53l-4.72-4.72H4.51c-.88 0-1.704-.507-1.938-1.354A9.009 9.009 0 0 1 2.25 12c0-.83.112-1.633.322-2.396C2.806 8.756 3.63 8.25 4.51 8.25H6.75Z"
              />
            </svg>
          ) : (
            // Speaker unmuted icon
            <svg
              className="h-6 w-6 text-white"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={1.5}
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M19.114 5.636a9 9 0 0 1 0 12.728M16.463 8.288a5.25 5.25 0 0 1 0 7.424M6.75 8.25l4.72-4.72a.75.75 0 0 1 1.28.53v15.88a.75.75 0 0 1-1.28.53l-4.72-4.72H4.51c-.88 0-1.704-.507-1.938-1.354A9.009 9.009 0 0 1 2.25 12c0-.83.112-1.633.322-2.396C2.806 8.756 3.63 8.25 4.51 8.25H6.75Z"
              />
            </svg>
          )}
        </button>

        {/* TOY branding - bottom right */}
        <div className="absolute bottom-4 right-4 text-white text-sm opacity-60 drop-shadow-md select-none pointer-events-none">
          Made with TOY
        </div>
      </div>
    </div>
  )
}
