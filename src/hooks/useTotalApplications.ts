import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';

interface TotalApplicationsMap {
  [internshipId: string]: number;
}

export const useTotalApplications = () => {
  const [totals, setTotals] = useState<TotalApplicationsMap>({});
  const [isLoading, setIsLoading] = useState(true);

  const fetchTotals = async () => {
    try {
      // Query all apply events, group by internship_id
      const { data, error } = await supabase
        .from('activity_logs')
        .select('internship_id')
        .eq('event', 'apply');

      if (error) throw error;

      // Aggregate counts
      const counts: TotalApplicationsMap = {};
      data?.forEach((row) => {
        const id = row.internship_id;
        counts[id] = (counts[id] || 0) + 1;
      });

      setTotals(counts);
    } catch (error) {
      console.error('Error fetching total applications:', error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchTotals();

    // Subscribe to real-time inserts to update counts live
    const channel = supabase
      .channel('total-applications-changes')
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

  return { totals, isLoading };
};
