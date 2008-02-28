select
  project
  , activity
  , sum( elapsed ) as elapsed
from nice_entries
where
  charge = true
  and invoice_number = 'CIM013'
group by project, activity
;
