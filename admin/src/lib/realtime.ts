import { useEffect } from 'react'
import { supabase } from './supabase'

export function useTableRealtime(table: string, onChange: () => void) {
  useEffect(() => {
    const channel = supabase
      .channel(`admin-${table}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table },
        () => onChange(),
      )
      .subscribe()
    return () => {
      supabase.removeChannel(channel)
    }
  }, [table, onChange])
}
