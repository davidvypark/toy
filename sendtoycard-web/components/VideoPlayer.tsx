'use client'

interface VideoPlayerProps {
  videoUrl: string
  recipientName: string
}

/**
 * Video player component with TOY branding and auto-play.
 * Placeholder - will be implemented in Task 2.
 */
export function VideoPlayer({ videoUrl, recipientName }: VideoPlayerProps) {
  return (
    <div className="mx-auto max-w-2xl">
      <video src={videoUrl} className="w-full aspect-video rounded-lg" />
      <p className="text-center mt-2 text-toy-text-secondary">
        Video for {recipientName}
      </p>
    </div>
  )
}
