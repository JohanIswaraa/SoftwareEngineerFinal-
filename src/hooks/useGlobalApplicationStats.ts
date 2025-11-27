import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';

interface GlobalApplicationStatsMap {
  [internshipId: string]: number;
}

export const useGlobalApplicationStats = () => {
  const [totals, setTotals] = useState<GlobalApplicationStatsMap>({});
  const [loading, setLoading] = useState(true);

  const fetchTotals = async () => {
    try {
      // Use the SECURITY DEFINER function to get global counts bypassing RLS
      const { data, error } = await supabase
        .rpc('get_global_application_counts');

      if (error) throw error;

      // Convert to map
      const counts: GlobalApplicationStatsMap = {};
      data?.forEach((row) => {
        counts[row.internship_id] = Number(row.application_count);
      });

      setTotals(counts);
    } catch (error) {
      console.error('Error fetching global application stats:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTotals();

    // Subscribe to real-time inserts to update counts live
    const channel = supabase
      .channel('global-applications-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'activity_logs',
        },
        (payload) => {
          // Only count 'apply' events
          if (payload.new.event === 'apply') {
            setTotals((prev) => ({
              ...prev,
              [payload.new.internship_id]: (prev[payload.new.internship_id] || 0) + 1,
            }));
          }
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'DELETE',
          schema: 'public',
          table: 'activity_logs',
        },
        () => {
          // Re-fetch on delete to ensure accuracy
          fetchTotals();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  return { totals, loading };
};
