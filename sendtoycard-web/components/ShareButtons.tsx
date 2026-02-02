'use client'

import { useState, useCallback, useEffect } from 'react'

interface ShareButtonsProps {
  shareUrl: string
  title: string
  recipientName: string
}

/**
 * Share buttons component for social media sharing.
 *
 * Features:
 * - Primary share button using Web Share API (when available)
 * - Direct platform buttons: Twitter/X, Facebook, WhatsApp
 * - Copy link button with "Copied!" feedback
 * - Responsive layout (wraps on mobile)
 */
export function ShareButtons({ shareUrl, title, recipientName }: ShareButtonsProps) {
  const [copied, setCopied] = useState(false)
  const [canShare, setCanShare] = useState(false)

  // Check if Web Share API is available (client-side only)
  useEffect(() => {
    setCanShare(typeof navigator !== 'undefined' && !!navigator.share)
  }, [])

  // Share text for platforms
  const shareText = `Check out this video for ${recipientName}: ${title}`

  // Handle native share
  const handleNativeShare = useCallback(async () => {
    if (navigator.share) {
      try {
        await navigator.share({
          title: `Video for ${recipientName}`,
          text: shareText,
          url: shareUrl,
        })
      } catch (err) {
        // User cancelled or share failed - silently ignore
        if ((err as Error).name !== 'AbortError') {
          console.error('Share failed:', err)
        }
      }
    }
  }, [shareUrl, shareText, recipientName])

  // Handle copy to clipboard
  const handleCopyLink = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(shareUrl)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch (err) {
      console.error('Copy failed:', err)
    }
  }, [shareUrl])

  // Platform share URLs
  const twitterUrl = `https://twitter.com/intent/tweet?url=${encodeURIComponent(shareUrl)}&text=${encodeURIComponent(shareText)}`
  const facebookUrl = `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}`
  const whatsappUrl = `https://wa.me/?text=${encodeURIComponent(`${shareText} ${shareUrl}`)}`

  return (
    <div className="flex flex-col items-center gap-4">
      {/* Primary share button (Web Share API) */}
      {canShare && (
        <button
          onClick={handleNativeShare}
          className="flex items-center gap-2 px-6 py-3 bg-toy-primary text-white rounded-full font-medium hover:bg-toy-primary-dark transition-colors"
        >
          <svg
            className="h-5 w-5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
            />
          </svg>
          Share Video
        </button>
      )}

      {/* Platform buttons */}
      <div className="flex flex-wrap justify-center gap-3">
        {/* Twitter/X */}
        <a
          href={twitterUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-2 px-4 py-2 bg-toy-surface border border-toy-text/10 rounded-full text-toy-text hover:bg-toy-background transition-colors"
          aria-label="Share on Twitter"
        >
          <svg className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
          </svg>
          <span className="text-sm font-medium">X</span>
        </a>

        {/* Facebook */}
        <a
          href={facebookUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-2 px-4 py-2 bg-toy-surface border border-toy-text/10 rounded-full text-toy-text hover:bg-toy-background transition-colors"
          aria-label="Share on Facebook"
        >
          <svg className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
          </svg>
          <span className="text-sm font-medium">Facebook</span>
        </a>

        {/* WhatsApp */}
        <a
          href={whatsappUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-2 px-4 py-2 bg-toy-surface border border-toy-text/10 rounded-full text-toy-text hover:bg-toy-background transition-colors"
          aria-label="Share on WhatsApp"
        >
          <svg className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
          </svg>
          <span className="text-sm font-medium">WhatsApp</span>
        </a>

        {/* Copy Link */}
        <button
          onClick={handleCopyLink}
          className="flex items-center gap-2 px-4 py-2 bg-toy-surface border border-toy-text/10 rounded-full text-toy-text hover:bg-toy-background transition-colors"
          aria-label="Copy link to clipboard"
        >
          {copied ? (
            <>
              <svg
                className="h-5 w-5 text-green-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={2}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="m4.5 12.75 6 6 9-13.5"
                />
              </svg>
              <span className="text-sm font-medium text-green-600">Copied!</span>
            </>
          ) : (
            <>
              <svg
                className="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={2}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M13.19 8.688a4.5 4.5 0 0 1 1.242 7.244l-4.5 4.5a4.5 4.5 0 0 1-6.364-6.364l1.757-1.757m13.35-.622 1.757-1.757a4.5 4.5 0 0 0-6.364-6.364l-4.5 4.5a4.5 4.5 0 0 0 1.242 7.244"
                />
              </svg>
              <span className="text-sm font-medium">Copy Link</span>
            </>
          )}
        </button>
      </div>
    </div>
  )
}
