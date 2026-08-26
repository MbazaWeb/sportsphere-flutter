// vps/api/src/routes/media.ts
// POST /v1/media/image   — upload + compress image (WebP, 3 variants)
// POST /v1/media/video   — upload video, store in MinIO (FFmpeg on Hetzner)
// DELETE /v1/media/:key  — delete a media object

import { Hono } from 'hono'
import { S3Client, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3'
import sharp from 'sharp'

export const mediaRouter = new Hono()

// ── S3/MinIO client ──────────────────────────────────────────────────────────
function s3() {
  return new S3Client({
    endpoint:        Bun.env.MINIO_ENDPOINT ?? 'http://localhost:9000',
    region:          Bun.env.MINIO_REGION   ?? 'us-east-1',
    credentials: {
      accessKeyId:     Bun.env.MINIO_ROOT_USER     ?? '',
      secretAccessKey: Bun.env.MINIO_ROOT_PASSWORD ?? '',
    },
    forcePathStyle: true,   // required for MinIO
  })
}

const CDN = () => Bun.env.CDN_BASE_URL ?? 'https://api.playify.app/storage'
const BUCKET = 'playify-media'

// Image variant specs — matches storage strategy from our schema design
const VARIANTS = {
  thumb: { width: 120,  quality: 70  },  // ~10 KB  — grid/list
  feed:  { width: 480,  quality: 78  },  // ~50 KB  — feed cards
  full:  { width: 1080, quality: 82  },  // ~120 KB — detail
}

// ── POST /v1/media/image ─────────────────────────────────────────────────────
mediaRouter.post('/image', async (c) => {
  const userId = c.get('userId') as string
  const formData = await c.req.parseBody()
  const file = formData['file'] as File | undefined
  const folder = (formData['folder'] as string) ?? 'posts'

  if (!file) return c.json({ error: 'file required' }, 400)
  if (file.size > 52_428_800) return c.json({ error: 'File exceeds 50 MB limit' }, 400)

  const allowed = ['image/jpeg','image/png','image/webp','image/gif']
  if (!allowed.includes(file.type)) {
    return c.json({ error: `Unsupported type: ${file.type}` }, 400)
  }

  const buf = Buffer.from(await file.arrayBuffer())
  const ts  = Date.now()
  const urls: Record<string, string> = {}
  const client = s3()

  for (const [variant, spec] of Object.entries(VARIANTS)) {
    const compressed = await sharp(buf)
      .rotate()                                           // auto-orient EXIF
      .resize({ width: spec.width, withoutEnlargement: true })
      .webp({ quality: spec.quality, effort: 4 })
      .toBuffer()

    const key = `${folder}/${userId}/${ts}/${variant}.webp`
    await client.send(new PutObjectCommand({
      Bucket:       BUCKET,
      Key:          key,
      Body:         compressed,
      ContentType:  'image/webp',
      CacheControl: 'public, max-age=31536000, immutable',
    }))
    urls[variant] = `${CDN()}/${key}`
  }

  return c.json({ ok: true, urls })   // { thumb, feed, full }
})

// ── POST /v1/media/avatar ────────────────────────────────────────────────────
mediaRouter.post('/avatar', async (c) => {
  const userId = c.get('userId') as string
  const formData = await c.req.parseBody()
  const file = formData['file'] as File | undefined

  if (!file) return c.json({ error: 'file required' }, 400)

  const buf = Buffer.from(await file.arrayBuffer())
  const compressed = await sharp(buf)
    .rotate()
    .resize({ width: 200, height: 200, fit: 'cover' })
    .webp({ quality: 80, effort: 4 })
    .toBuffer()

  const key = `avatars/${userId}.webp`
  await s3().send(new PutObjectCommand({
    Bucket:       BUCKET,
    Key:          key,
    Body:         compressed,
    ContentType:  'image/webp',
    CacheControl: 'public, max-age=86400',
  }))
  return c.json({ ok: true, url: `${CDN()}/${key}` })
})

// ── POST /v1/media/video ─────────────────────────────────────────────────────
// Stores video directly — FFmpeg transcoding is a separate worker job
mediaRouter.post('/video', async (c) => {
  const userId = c.get('userId') as string
  const formData = await c.req.parseBody()
  const file = formData['file'] as File | undefined
  const postId = (formData['postId'] as string) ?? `${userId}-${Date.now()}`

  if (!file) return c.json({ error: 'file required' }, 400)
  if (file.size > 104_857_600) return c.json({ error: 'File exceeds 100 MB limit' }, 400)

  const buf = Buffer.from(await file.arrayBuffer())
  const key = `videos/${postId}/video.${file.name.split('.').pop() ?? 'mp4'}`

  await s3().send(new PutObjectCommand({
    Bucket:       BUCKET,
    Key:          key,
    Body:         buf,
    ContentType:  file.type || 'video/mp4',
    CacheControl: 'public, max-age=31536000, immutable',
  }))
  return c.json({ ok: true, url: `${CDN()}/${key}`, key })
})

// ── DELETE /v1/media/:key ────────────────────────────────────────────────────
mediaRouter.delete('/:key{.+}', async (c) => {
  const key = c.req.param('key')
  await s3().send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key }))
  return c.json({ ok: true, deleted: key })
})
