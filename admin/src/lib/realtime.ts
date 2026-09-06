import { useEffect, useRef } from 'react'
export function useTableRealtime(table: string, onChange: () => void) {
  const callback = useRef(onChange)
  callback.current = onChange
  useEffect(() => {
    const timer = window.setInterval(() => { if (!document.hidden) callback.current() }, 15000)
    return () => window.clearInterval(timer)
  }, [table])
}
