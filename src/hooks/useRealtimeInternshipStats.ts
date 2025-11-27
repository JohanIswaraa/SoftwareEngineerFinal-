import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";

interface StatsMap {
  [internshipId: string]: {
    applies: number;
  };
}

export const useRealtimeInternshipStats = () => {
  const [stats, setStats] = useState<StatsMap>({});
  const [loading, setLoading] = useState(true);

  const fetchInitial = async () => {
    try {
      const { data, error } = await supabase.from("activity_logs").select("internship_id").eq("event", "apply");

      if (error) throw error;

      const map: StatsMap = {};

      data.forEach((row) => {
        if (!row.internship_id) return;
        map[row.internship_id] = {
          applies: (map[row.internship_id]?.applies || 0) + 1,
        };
      });

      setStats(map);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchInitial();

    const channel = supabase
      .channel("realtime-apply-count")
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "activity_logs",
        },
        (payload) => {
          if (payload.new.event !== "apply") return;

          const internshipId = payload.new.internship_id;

          setStats((prev) => ({
            ...prev,
            [internshipId]: {
              applies: (prev[internshipId]?.applies || 0) + 1,
            },
          }));
        },
      )
      .on(
        "postgres_changes",
        {
          event: "DELETE",
          schema: "public",
          table: "activity_logs",
        },
        () => {
          fetchInitial();
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  return { stats, loading };
};
