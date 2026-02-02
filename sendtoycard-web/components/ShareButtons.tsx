'use client'

interface ShareButtonsProps {
  shareUrl: string
  title: string
  recipientName: string
}

/**
 * Share buttons component for social sharing.
 * Placeholder - will be implemented in Task 3.
 */
export function ShareButtons({ shareUrl, title, recipientName }: ShareButtonsProps) {
  return (
    <div className="flex justify-center gap-4">
      <button className="px-4 py-2 bg-toy-primary text-white rounded-full">
        Share
      </button>
    </div>
  )
}
