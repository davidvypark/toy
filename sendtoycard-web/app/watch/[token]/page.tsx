import { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { createServerClient } from '@/lib/supabase'
import { VideoPlayer } from '@/components/VideoPlayer'
import { ShareButtons } from '@/components/ShareButtons'

interface Card {
  id: string
  title: string
  recipient_name: string
  video_url: string
  share_token: string
  status: string
  host_id: string
  occasion: string | null
  published_at: string | null
}

interface PageProps {
  params: Promise<{ token: string }>
}

/**
 * Fetches a published card by its share token.
 * Returns null if card not found or not published.
 */
async function getCard(shareToken: string): Promise<Card | null> {
  const supabase = createServerClient()

  const { data, error } = await supabase
    .from('cards')
    .select('*')
    .eq('share_token', shareToken)
    .eq('status', 'published')
    .single()

  if (error || !data) {
    return null
  }

  return data as Card
}

/**
 * Generates a signed URL for the video from the videos bucket.
 * The signed URL is valid for 1 hour.
 */
async function getSignedVideoUrl(videoPath: string): Promise<string | null> {
  const supabase = createServerClient()

  const { data, error } = await supabase
    .storage
    .from('videos')
    .createSignedUrl(videoPath, 60 * 60) // 1 hour

  if (error || !data?.signedUrl) {
    console.error('Failed to create signed URL:', error)
    return null
  }

  return data.signedUrl
}

/**
 * Generate dynamic metadata for social sharing.
 */
export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { token } = await params
  const card = await getCard(token)

  if (!card) {
    return {
      title: 'Video Not Found | TOY',
      description: 'This video may not exist or has not been published yet.',
    }
  }

  const title = `A video for ${card.recipient_name} | TOY`
  const description = card.title

  return {
    title,
    description,
    openGraph: {
      title,
      description,
      siteName: 'TOY - Thinking Of You',
      type: 'video.other',
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
    },
  }
}

/**
 * Video viewer page for recipients.
 * Displays the published video with TOY branding and share buttons.
 */
export default async function WatchPage({ params }: PageProps) {
  const { token } = await params
  const card = await getCard(token)

  if (!card) {
    notFound()
  }

  // Get signed URL for video
  // video_url stores the path within the videos bucket (e.g., "{cardId}/montage.mp4")
  if (!card.video_url) {
    notFound()
  }

  const signedVideoUrl = await getSignedVideoUrl(card.video_url)

  if (!signedVideoUrl) {
    notFound()
  }

  // Construct the shareable URL
  const shareUrl = `https://sendtoycard.com/watch/${token}`

  return (
    <main className="min-h-screen bg-toy-background">
      {/* Header */}
      <header className="py-6 text-center">
        <h1 className="text-2xl font-serif text-toy-text">
          A video for <span className="text-toy-primary">{card.recipient_name}</span>
        </h1>
        <p className="mt-2 text-toy-text-secondary">{card.title}</p>
      </header>

      {/* Video Player */}
      <section className="px-4 pb-8">
        <VideoPlayer
          videoUrl={signedVideoUrl}
          recipientName={card.recipient_name}
        />
      </section>

      {/* Share Section */}
      <section className="px-4 pb-12">
        <div className="mx-auto max-w-2xl">
          <h2 className="mb-4 text-center text-lg font-serif text-toy-text">
            Share this video
          </h2>
          <ShareButtons
            shareUrl={shareUrl}
            title={card.title}
            recipientName={card.recipient_name}
          />
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 text-center border-t border-toy-text/10">
        <p className="text-sm text-toy-text-secondary">
          Made with{' '}
          <a
            href="https://sendtoycard.com"
            className="text-toy-primary hover:text-toy-primary-dark transition-colors"
          >
            TOY
          </a>
          {' '}- Thinking Of You
        </p>
      </footer>
    </main>
  )
}
