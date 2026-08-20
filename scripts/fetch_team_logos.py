#!/usr/bin/env python3
"""
Download team logos from source URLs, upload to Supabase Storage (media/teams/),
and update Team.logoUrl + team account avatars + welcome post media.

Usage:
  export SUPABASE_URL=https://xxx.supabase.co
  export SUPABASE_SERVICE_ROLE_KEY=eyJ...
  export DATABASE_URL=postgresql://...
  python scripts/fetch_team_logos.py

Optional:
  python scripts/fetch_team_logos.py --only kagera-sugar,pamba-jiji
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import requests

try:
    import psycopg2
except ImportError:
    print('pip install psycopg2-binary requests', file=sys.stderr)
    raise

# Flashscore (and future) source map: team id -> (slug, source_url)
LOGO_SOURCES: dict[str, tuple[str, str]] = {
    'tm-simba': ('simba-sc', 'https://static.flashscore.com/res/image/data/h0XI4TFG-6auKd00m.png'),
    'tm-sbs': ('singida-black-stars', 'https://static.flashscore.com/res/image/data/KMDOZqjl-bFuPDM8N.png'),
    'tm-yanga': ('young-africans', 'https://static.flashscore.com/res/image/data/S8uWjZWg-EmiHOeHk.png'),
    'tm-mbeya-city': ('mbeya-city', 'https://static.flashscore.com/res/image/data/nPlZdkAr-zRkl1WzG.png'),
    'tm-geita': ('geita-gold', 'https://static.flashscore.com/res/image/data/0hF9asf5-rmL4ZAyt.png'),
    'tm-mashujaa': ('mashujaa-fc', 'https://static.flashscore.com/res/image/data/6e3ag3jl-b3Pt3BpO.png'),
    'tm-namungo': ('namungo-fc', 'https://static.flashscore.com/res/image/data/ry5BcZf5-xvhpN1dm.png'),
    'tm-fgate': ('fountain-gate', 'https://static.flashscore.com/res/image/data/0QjLg3EG-f91acHAB.png'),
    'tm-azam': ('azam-fc', 'https://static.flashscore.com/res/image/data/dp2pkvCr-GMblXjD2.png'),
    'tm-polisi': ('polisi-tanzania', 'https://static.flashscore.com/res/image/data/K8BbMyg5-OYAKBJym.png'),
    'tm-jkt': ('jkt-tanzania', 'https://static.flashscore.com/res/image/data/C0AxGBCa-fP9GHZ7S.png'),
    'tm-tra': ('tra-united', 'https://static.flashscore.com/res/image/data/UV5Amce5-8Ksswm83.png'),
    'tm-pamba': ('pamba-jiji', 'https://static.flashscore.com/res/image/data/GASUZmHG-xSwXh9tB.png'),
    'tm-kagera': ('kagera-sugar', 'https://static.flashscore.com/res/image/data/lI67seh5-zRkl1WzG.png'),
    'tm-dodoma': ('dodoma-jiji', 'https://static.flashscore.com/res/image/data/d0npsVh5-0SL5ozs0.png'),
    'tm-coastal': ('coastal-union', 'https://static.flashscore.com/res/image/data/UZWSnHHG-dzip2CL9.png'),
}


def env(name: str) -> str:
    v = os.environ.get(name, '').strip()
    if not v:
        raise SystemExit(f'Missing env {name}')
    return v


def upload_logo(supabase_url: str, service_key: str, slug: str, content: bytes, content_type: str) -> str:
    if 'jpeg' in content_type or 'jpg' in content_type:
        ext = 'jpg'
    elif 'webp' in content_type:
        ext = 'webp'
    else:
        ext = 'png'
        content_type = 'image/png'
    path = f'teams/{slug}.{ext}'
    headers = {
        'apikey': service_key,
        'Authorization': f'Bearer {service_key}',
        'Content-Type': content_type,
        'x-upsert': 'true',
    }
    for method in (requests.post, requests.put):
        r = method(
            f'{supabase_url}/storage/v1/object/media/{path}',
            headers=headers,
            data=content,
            timeout=60,
        )
        if r.status_code in (200, 201):
            return f'{supabase_url}/storage/v1/object/public/media/{path}'
    raise RuntimeError(f'upload failed {slug}: {r.status_code} {r.text[:200]}')


def sync_db(dsn: str, team_id: str, public_url: str) -> None:
    conn = psycopg2.connect(dsn)
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute('update public."Team" set "logoUrl"=%s where "id"=%s', (public_url, team_id))
    cur.execute(
        'update public."Post" set "mediaUrls"=%s::jsonb where "id"=%s',
        (json.dumps([public_url]), f'welcome-{team_id}'),
    )
    cur.execute(
        '''
        update public."User" u
        set "avatarUrl"=%s, "updatedAt"=now()
        from public."Team" t
        where t."id"=%s and t."accountUserId"=u."id"
        ''',
        (public_url, team_id),
    )
    cur.execute(
        '''
        update public.profiles p
        set avatar_url=%s
        from public."Team" t
        where t."id"=%s and t."accountUserId"=p.id::text
        ''',
        (public_url, team_id),
    )
    cur.close()
    conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(description='Fetch and store team logos')
    parser.add_argument('--only', help='Comma-separated slugs to process', default='')
    args = parser.parse_args()
    only = {s.strip() for s in args.only.split(',') if s.strip()}

    supabase_url = env('SUPABASE_URL').rstrip('/')
    service_key = env('SUPABASE_SERVICE_ROLE_KEY')
    dsn = env('DATABASE_URL')

    ok = fail = 0
    for team_id, (slug, src) in LOGO_SOURCES.items():
        if only and slug not in only:
            continue
        try:
            img = requests.get(src, timeout=30, headers={'User-Agent': 'SportSphereLogoBot/1.0'})
            img.raise_for_status()
            ctype = img.headers.get('Content-Type', 'image/png')
            public = upload_logo(supabase_url, service_key, slug, img.content, ctype)
            sync_db(dsn, team_id, public)
            print(f'OK  {slug}  {len(img.content)}b  {public}')
            ok += 1
        except Exception as e:
            print(f'FAIL {slug}: {e}', file=sys.stderr)
            fail += 1
    print(f'Done ok={ok} fail={fail}')
    if fail:
        sys.exit(1)


if __name__ == '__main__':
    main()
