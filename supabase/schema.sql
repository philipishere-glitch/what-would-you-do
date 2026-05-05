-- Would You Do? Supabase setup
-- Paste this whole file into Supabase SQL Editor and run it.

create extension if not exists pgcrypto;

create table if not exists public.scenarios (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  option_a text not null,
  option_b text not null,
  category text not null default 'Life',
  intensity int not null default 3 check (intensity between 1 and 5),
  ai_take text not null default '',
  is_active boolean not null default true,
  sort_order int not null default 1000,
  created_at timestamptz not null default now()
);

create table if not exists public.votes (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references public.scenarios(id) on delete cascade,
  device_id text not null,
  choice text not null check (choice in ('A','B')),
  created_at timestamptz not null default now(),
  unique (scenario_id, device_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid references public.scenarios(id) on delete cascade,
  device_id text,
  reason text,
  created_at timestamptz not null default now()
);

create or replace view public.scenario_stats as
select
  s.*,
  count(v.*) filter (where v.choice = 'A')::int as votes_a,
  count(v.*) filter (where v.choice = 'B')::int as votes_b,
  count(v.*)::int as total_votes
from public.scenarios s
left join public.votes v on v.scenario_id = s.id
group by s.id;

alter table public.scenarios enable row level security;
alter table public.votes enable row level security;
alter table public.reports enable row level security;

-- Public can read only active scenarios. Keep admin editing in the Supabase dashboard.
drop policy if exists "Read active scenarios" on public.scenarios;
create policy "Read active scenarios" on public.scenarios for select using (is_active = true);

-- Anonymous users can vote once per scenario per device. This is intentionally simple for MVP speed.
drop policy if exists "Insert anonymous votes" on public.votes;
create policy "Insert anonymous votes" on public.votes for insert with check (true);

drop policy if exists "Update own anonymous vote" on public.votes;
create policy "Update own anonymous vote" on public.votes for update using (true) with check (true);

-- Needed so the stats view can aggregate votes through the public API.
drop policy if exists "Read vote counts" on public.votes;
create policy "Read vote counts" on public.votes for select using (true);

drop policy if exists "Insert reports" on public.reports;
create policy "Insert reports" on public.reports for insert with check (true);

insert into public.scenarios (title, option_a, option_b, category, intensity, ai_take, sort_order) values
('Your manager presents your idea in a meeting as their own. You are in the room.', 'Call it out immediately', 'Let it go and raise it later', 'Work', 4, 'Public correction feels satisfying, but private documentation usually protects you better.', 10),
('You are offered a promotion, but no salary increase “for now.”', 'Accept and prove yourself', 'Push back before accepting', 'Work', 4, 'A title without money can still help later, but accepting vague promises weakens your leverage.', 20),
('A colleague you like is clearly underperforming and it is affecting your project.', 'Cover for them', 'Escalate it', 'Work', 3, 'Covering once builds trust. Covering repeatedly quietly makes the problem yours.', 30),
('Your boss messages you on vacation about something that is not urgent.', 'Reply quickly', 'Ignore until you return', 'Work', 2, 'Boundaries are easier to keep when they are consistent before there is a crisis.', 40),
('A recruiter offers you an interview for a better-paid role while your team is already stretched.', 'Take the interview', 'Stay loyal for now', 'Work', 3, 'An interview is information, not betrayal.', 50),
('Someone you are dating becomes less responsive after a great weekend together.', 'Call it out directly', 'Match their energy', 'Dating', 3, 'Directness gives clarity; matching energy protects dignity but can become a silent game.', 60),
('You see your partner texting someone they previously said was “nothing.”', 'Ask directly', 'Wait and observe', 'Relationships', 4, 'Direct questions reveal more than surveillance, but tone determines whether it becomes a fight.', 70),
('Your friend’s partner is cheating and your friend has no idea.', 'Tell your friend', 'Stay out of it', 'Friendship', 5, 'Silence avoids drama now but can look like betrayal later.', 80),
('A friend always cancels plans last minute but expects you to be available for them.', 'Confront them', 'Stop making plans', 'Friendship', 2, 'A direct pattern callout is cleaner than a quiet disappearance.', 90),
('Your ex likes your social posts right after you start dating someone new.', 'Ignore it', 'Ask what they want', 'Dating', 2, 'Ambiguous attention is often bait. Respond only if you actually want the conversation.', 100),
('At dinner, someone makes a subtle offensive comment and nobody reacts.', 'Call it out', 'Let it pass', 'Social', 4, 'A small calm challenge can reset the room without turning it into a performance.', 110),
('You find $200 on the floor in a store with no one nearby.', 'Keep it', 'Try to return it', 'Morality', 3, 'The question is less about being caught and more about who you are when no one knows.', 120),
('A cashier forgets to charge you for an expensive item.', 'Go back and pay', 'Take the win', 'Morality', 3, 'Small dishonest wins have a way of becoming part of your self-story.', 130),
('A stranger is being rude to service staff in front of you.', 'Say something', 'Stay out of it', 'Social', 3, 'Intervening works best when you support the target, not attack the aggressor.', 140),
('Your group chat starts mocking someone who is not there.', 'Push back', 'Stay quiet', 'Social', 2, 'Silence keeps you comfortable, but it also teaches people what you tolerate.', 150),
('Your co-parent makes a school decision without telling you.', 'Confront immediately', 'Address calmly later', 'Parenting', 4, 'Urgency feels justified, but a documented calm response usually ages better.', 160),
('Your child lies about something small to avoid trouble.', 'Punish the lie', 'Understand why first', 'Parenting', 3, 'The lie matters, but the fear behind it often tells you what needs fixing.', 170),
('Another parent criticizes your child’s behavior in public.', 'Defend your child immediately', 'Listen first', 'Parenting', 4, 'Defend dignity, but do not accidentally defend behavior you have not understood.', 180),
('Your kid wants to quit an activity after you already paid for the season.', 'Make them finish', 'Let them quit', 'Parenting', 2, 'Finishing teaches commitment; quitting can teach self-awareness if handled deliberately.', 190),
('A teacher gives feedback you think is unfair.', 'Challenge it', 'Ask for examples first', 'Parenting', 3, 'Examples turn emotion into specifics.', 200),
('A friend asks to borrow a significant amount of money.', 'Lend it', 'Say no kindly', 'Money', 5, 'Money tests relationships. A gift-sized amount is safer than a loan-sized resentment.', 210),
('You can invest early in something risky but promising.', 'Go in', 'Stay safe', 'Money', 4, 'Risk should be sized so being wrong does not wreck your life.', 220),
('Your partner is worse with money than you and wants a shared account.', 'Agree', 'Keep finances separate', 'Money', 4, 'Shared accounts amplify trust and amplify chaos.', 230),
('A family member asks you to co-sign a loan.', 'Help them', 'Refuse', 'Money', 5, 'Co-signing means you are accepting the debt, not just supporting the person.', 240),
('You receive a much larger refund than expected and suspect it is a mistake.', 'Keep quiet', 'Report it', 'Money', 3, 'Found money becomes stress when someone can ask for it back.', 250),
('Your team takes credit for work mostly done by one quiet person.', 'Name them publicly', 'Let the team share credit', 'Work', 3, 'Naming contribution costs little and builds rare trust.', 260),
('A close friend shares a secret that could hurt someone else.', 'Keep the secret', 'Warn the person affected', 'Friendship', 5, 'Loyalty to one person can become harm to another.', 270),
('You get invited to a wedding you cannot afford to attend.', 'Go anyway', 'Decline honestly', 'Money', 2, 'Real friends should not require financial self-harm as proof of love.', 280),
('A date says something that conflicts with your core values, but chemistry is strong.', 'Keep seeing them', 'End it early', 'Dating', 4, 'Chemistry can hide incompatibility, but values usually collect interest over time.', 290),
('Your sibling expects you to handle care for an aging parent because you are “better at it.”', 'Accept the role', 'Demand shared responsibility', 'Family', 5, 'Competence often gets punished with more work unless boundaries are explicit.', 300),
('A friend asks for honest feedback on a bad business idea.', 'Be brutally honest', 'Be supportive', 'Friendship', 3, 'Kind truth beats comfortable encouragement when real money is involved.', 310),
('You accidentally see a confidential salary document showing you are underpaid.', 'Use it to negotiate', 'Pretend you never saw it', 'Work', 5, 'The information is useful, but how you use it determines your risk.', 320),
('Your partner wants to check your phone to “rebuild trust.”', 'Let them', 'Say no', 'Relationships', 4, 'Transparency can help repair trust, but surveillance rarely creates security.', 330),
('Your friend is constantly late and laughs it off.', 'Set a hard boundary', 'Accept that this is who they are', 'Friendship', 2, 'Chronic lateness becomes a respect issue when there is no repair.', 340),
('Someone cuts in line in front of you when you are already stressed.', 'Confront them', 'Let it go', 'Social', 1, 'Not every win is worth the emotional transaction fee.', 350),
('Your company asks you to train someone who may replace part of your role.', 'Help fully', 'Protect your knowledge', 'Work', 4, 'Being useful matters, but so does making your value visible beyond the task.', 360),
('Your child says they prefer the other parent’s house because there are fewer rules.', 'Loosen your rules', 'Stay consistent', 'Parenting', 4, 'Popularity and parenting are different games.', 370),
('You learn a friend exaggerated their resume to get a job.', 'Call them out', 'Let them handle consequences', 'Morality', 3, 'The risk belongs to them unless their lie directly harms someone else.', 380),
('A neighbor constantly parks in your spot but acts friendly.', 'Leave a note', 'Speak face to face', 'Social', 2, 'Friendly confrontation usually beats anonymous escalation.', 390),
('You are exhausted but promised to attend a friend’s important event.', 'Show up', 'Cancel and apologize', 'Friendship', 3, 'Reliability matters, but resentment can poison a gesture.', 400),
('Your boss praises your work privately but never in front of leadership.', 'Ask for public recognition', 'Keep performing', 'Work', 3, 'Invisible excellence is a trap when advancement depends on perception.', 410),
('You discover your partner has debt they never mentioned.', 'Pause the relationship', 'Work through it', 'Relationships', 5, 'The debt matters; the secrecy may matter more.', 420),
('A friend posts an unflattering photo of you and refuses to delete it.', 'Demand removal', 'Let it go', 'Social', 2, 'Consent is not vanity. It is basic respect.', 430),
('A client is rude but highly profitable.', 'Keep them', 'Fire them', 'Work', 4, 'Bad clients often spend money and morale at the same time.', 440),
('You can take a shortcut that nobody will notice but slightly lowers quality.', 'Take the shortcut', 'Do it properly', 'Work', 2, 'Standards are mostly built when nobody is checking.', 450),
('Your friend keeps asking for advice but never takes it.', 'Stop advising', 'Keep trying', 'Friendship', 2, 'Sometimes people want witnesses, not solutions.', 460),
('A family member makes jokes at your expense and says you are too sensitive.', 'Call it out', 'Laugh along', 'Family', 3, 'Humor that only works when one person absorbs the cost is not harmless.', 470),
('You see someone attractive flirting with you while you are in a relationship.', 'Shut it down', 'Enjoy the attention', 'Relationships', 4, 'The danger often starts before anything technically happens.', 480),
('You are offered cash for a side job and asked not to invoice.', 'Accept cash', 'Insist on doing it properly', 'Money', 3, 'Easy money gets less easy when records matter.', 490),
('A teammate confides they are interviewing elsewhere and asks you not to tell.', 'Keep quiet', 'Warn your manager', 'Work', 3, 'Confidentiality here is usually appropriate unless there is direct operational risk.', 500);
