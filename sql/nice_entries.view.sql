drop view nice_entries;
CREATE VIEW nice_entries AS
   SELECT
		entries.id
		, invoices.invoice_number
		, invoices.status
		, projects.project
		, activities.activity
		, cast (entries."end" - entries."start" as time ) as elapsed
		, entries.date
		, entries."start"
		, entries."end"
		, entries.description
		, entries.person
		, entries.order_number
		, entries.out_of_spec
		, entries.module
		, entries.rate
		, entries.charge
	FROM
		(entries JOIN activities ON entries.activity_id = activities.id)
		JOIN projects ON entries.project_id = projects.id
		JOIN invoices ON entries.invoice_id = invoices.id
;
