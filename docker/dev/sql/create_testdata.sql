CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$
DECLARE
  total_users INTEGER := 1000;
  total_groups INTEGER := 100;
  users_per_group INTEGER := 20;
  expenses_per_group INTEGER := 500;

  my_user_id INTEGER;
  user_id INTEGER;
  group_id INTEGER;
  expense_id TEXT;

  part_id INT;
  part_amount INT;
  net_amount INT;
  curr TEXT := 'USD';
BEGIN

  -- Get your existing user (adjust email!)
  SELECT id INTO my_user_id FROM "User" WHERE email = 'XXXXX';
  IF my_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found. Adjust the email in the script.';
  END IF;

  FOR i IN 1..total_users LOOP
    INSERT INTO "User" ("name", email, "emailVerified", image)
    VALUES (
      'User ' || i,
      'user' || i || '@example.com',
      now(),
      'https://example.com/avatar/' || i
    )
    ON CONFLICT (email) DO NOTHING;
  END LOOP;

  FOR g IN 1..total_groups LOOP
    user_id := (SELECT id FROM "User" ORDER BY random() LIMIT 1);
    INSERT INTO "Group" ("publicId", "name", "userId", "createdAt", "updatedAt", "defaultCurrency")
    VALUES (
      'group_' || g,
      'Group ' || g,
      user_id,
      now(),
      now(),
      curr
    )
    RETURNING id INTO group_id;

    INSERT INTO "GroupUser" ("groupId", "userId")
    VALUES (group_id, my_user_id)
    ON CONFLICT DO NOTHING;

    FOR u IN 1..users_per_group LOOP
      user_id := (SELECT id FROM "User" ORDER BY random() LIMIT 1);
      INSERT INTO "GroupUser" ("groupId", "userId")
      VALUES (group_id, user_id)
      ON CONFLICT DO NOTHING;
    END LOOP;

    FOR e IN 1..expenses_per_group LOOP
      user_id := (SELECT "userId" FROM "GroupUser" WHERE "groupId" = group_id ORDER BY random() LIMIT 1);
      expense_id := gen_random_uuid()::TEXT;

      INSERT INTO "Expense" (
        id, "paidBy", "addedBy", name, category, amount, currency,
        "createdAt", "updatedAt", "expenseDate", "splitType", "groupId"
      )
      VALUES (
        expense_id,
        user_id,
        user_id,
        'Expense ' || e,
        'test',
        (RANDOM() * 10000)::INT,
        curr,
        now(),
        now(),
        now(),
        'EQUAL',
        group_id
      );

      FOR part_id IN
        SELECT "userId" FROM "GroupUser" WHERE "groupId" = group_id AND "userId" != my_user_id ORDER BY random() LIMIT 4
      LOOP
        INSERT INTO "ExpenseParticipant" ("expenseId", "userId", amount)
        VALUES (
          expense_id,
          part_id,
          (SELECT amount FROM "Expense" WHERE id = expense_id) / 5
        );
      END LOOP;

      INSERT INTO "ExpenseParticipant" ("expenseId", "userId", amount)
      VALUES (
        expense_id,
        my_user_id,
        (SELECT amount FROM "Expense" WHERE id = expense_id) / 5
      );
    END LOOP;
  END LOOP;

WITH balances AS (
  SELECT
    e."groupId",
    e.currency,
    ep."userId" AS "userId",
    e."paidBy"  AS "firendId",
    SUM(ep.amount) AS amount
  FROM "Expense" e
  JOIN "ExpenseParticipant" ep ON ep."expenseId" = e.id
  WHERE ep."userId" != e."paidBy"
  GROUP BY e."groupId", e.currency, ep."userId", e."paidBy"
)
INSERT INTO "GroupBalance" ("groupId", currency, "userId", "firendId", amount, "updatedAt")
SELECT "groupId", currency, "userId", "firendId", amount, now()
FROM balances
ON CONFLICT ("groupId", currency, "userId", "firendId")
DO UPDATE SET amount = "GroupBalance".amount + EXCLUDED.amount, "updatedAt" = now();

WITH balances AS (
  SELECT
    e."groupId",
    e.currency,
    ep."userId" AS "userId",
    e."paidBy"  AS "firendId",
    SUM(ep.amount) AS amount
  FROM "Expense" e
  JOIN "ExpenseParticipant" ep ON ep."expenseId" = e.id
  WHERE ep."userId" != e."paidBy"
  GROUP BY e."groupId", e.currency, ep."userId", e."paidBy"
)
INSERT INTO "GroupBalance" ("groupId", currency, "userId", "firendId", amount, "updatedAt")
SELECT "groupId", currency, "firendId", "userId", -amount, now()
FROM balances
ON CONFLICT ("groupId", currency, "userId", "firendId")
DO UPDATE SET amount = "GroupBalance".amount + EXCLUDED.amount, "updatedAt" = now();
END $$;