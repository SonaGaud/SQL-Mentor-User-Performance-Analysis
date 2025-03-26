
-- SQL Mentor User Performance Analysis
-- --------------------------------------
-- This script analyzes user performance based on their SQL submissions.
-- It includes various queries to extract insights such as user rankings, submission counts, and daily performance.

-- Table Creation --

create table user_submissions(
    id serial primary key,
    user_id bigint,
    question_id int,
    points int,
    submitted_at timestamp with time zone,
    username varchar(50));

select * from user_submissions;

select count(id) from user_submissions;

-- Q1. List all Distinct Users And Their Stats (Return user_name, total_submissions, points earned)
-- Learning: This query retrieves distinct usernames along with their total number of submissions and total 
-- points earned.
-- Function Used: COUNT() - Counts the number of submissions, SUM() - Calculates the total points earned.
select username, count(id) as total_submissions, sum(points) as points_earned 
from user_submissions 
group by username order by total_submissions desc, points_earned desc;

-- Q2. Calculate The Daily Average Points For Each User.
-- Learning: Helps in understanding user performance trends over time.
-- Function Used: TO_CHAR() - Extracts date in a readable format, AVG() - Calculates the average points.
select to_char(submitted_at, 'DD-MM') as day, username, 
       round(avg(points), 2) as daily_avg_points 
from user_submissions 
group by 1, 2 order by username;

-- Q3. Determine The Percentage Of Submissions That Resulted In Positive, Negative, And Neutral Points.
-- Learning: Provides a breakdown of submission outcomes, helping to analyze user accuracy and engagement trends.
-- Function Used: SUM() - Counts different types of submissions, ROUND() - Formats results for better readability.
select 
    round((sum(case when points > 0 then 1 else 0 end) * 100.0) / count(*), 2) as positive_submission_percentage,
    round((sum(case when points < 0 then 1 else 0 end) * 100.0) / count(*), 2) as negative_submission_percentage,
    round((sum(case when points = 0 then 1 else 0 end) * 100.0) / count(*), 2) as neutral_submission_percentage
from user_submissions;

-- Q4. Find The User Who Submitted The Most Solutions In A Single Day.
-- Learning: Helps identify the most active users on a daily basis, useful for engagement analysis.
-- Function Used: COUNT() - Counts submissions per day.
select username, TO_CHAR(submitted_at, 'DD-MM-YYYY') as submission_date, 
       count(*) as total_submissions 
from user_submissions 
group by username, submission_date order by total_submissions desc limit 1;

-- Q5. Identify The Top 3 Questions With The Highest Average Points Per Submission.
-- Learning: Finds the highest-rated questions, useful for identifying well-scored problems.
-- Function Used: AVG() - Calculates average points per question.
select question_id, round(avg(points), 2) as avg_points from user_submissions 
group by question_id order by avg_points desc LIMIT 3;

-- Q6. Find The Top 3 Users With The Most Correct Submissions For Each Day.
-- Learning: Ranks users using DENSE_RANK() to ensure multiple users with the same score are equally ranked.
-- Function Used: SUM() - Counts positive submissions, DENSE_RANK() - Ranks users within each day.
with daily_submissions as(
    select TO_CHAR(submitted_at, 'DD-MM') as daily, username,
           sum(case when points > 0 then 1 else 0 end) as correct_submissions
    from user_submissions
    group by 1, 2
),
users_rank as(
    select daily, username, correct_submissions,
           dense_rank() over (partition by daily order by correct_submissions desc) as rank
    from daily_submissions
)
select daily, username, correct_submissions   
from users_rank where rank <= 3;

-- Q7. Find The Top 5 Users With The Highest Number Of Incorrect & Correct Submissions.
-- Learning: Identifies users who may need additional support.
-- Function Used: SUM() - Counts incorrect submissions.
select username,
    sum(case when points < 0 then 1 else 0 end) as incorrect_submissions,
    sum(case when points > 0 then 1 else 0 end) as correct_submissions,
    sum(case when points < 0 then points else 0 end) as incorrect_submissions_points,
    sum(case when points > 0 then points else 0 end) as correct_submissions_points_earned,
    sum(points) as points_earned
from user_submissions
group by username order by incorrect_submissions desc limit 5;

-- Q8. Find The Top 10 Performers For Each Week.
-- Learning: Ranks top performers each week based on total points.
-- Function Used: EXTRACT() - Extracts week number, SUM() - Calculates total points, DENSE_RANK() - Ranks users.
select * from(
              select extract(week from submitted_at) as week_no, username,
              sum(points) as total_points_earned,
              dense_rank() over(partition by extract(week from submitted_at) 
			  order by sum(points) desc)as rank
    from user_submissions
    group by 1, 2 order by week_no, total_points_earned desc
)ranked_users where rank <= 10;

-- Q9. Find The User With The Highest Total Points Earned.
-- Learning: Identifies the highest overall performer in terms of points accumulated.
-- Function Used: SUM() - Calculates total points earned by each user.
select username, sum(points) as total_points 
from user_submissions 
group by username order by total_points desc limit 1;

-- Q10. Find The Day With The Highest Number Of Submissions.
-- Learning: Helps determine peak activity periods among users.
-- Function Used: COUNT() - Counts the number of submissions per day.
select TO_CHAR(submitted_at, 'DD-MM') as submission_day, count(*) as total_submissions 
from user_submissions 
group by 1 order by total_submissions desc limit 1;

-- Q11. Identify The User With The Longest Active Streak(Submitting On Consecutive Days).
-- Learning: Determines consistency and engagement of users over time.
-- Function Used: LAG() - Compares submission dates to find consecutive days, COUNT() - Calculates the longest streak.
with submission_dates as(
    select username, submitted_at::date as submission_date, 
           lag(submitted_at::date) over(partition by username order by submitted_at) as prev_date
    from user_submissions
),

streaks as(
    select username, submission_date, 
           (submission_date - prev_date) = 1 as is_consecutive
    from submission_dates
)

select username, count(*) as longest_streak from streaks
where is_consecutive group by username order by longest_streak desc limit 1;

--Q12. Find Users Who Have Never Submitted An Incorrect Answer.
-- Learning: This query identifies users who have never received negative points, indicating high accuracy and careful submission.
-- Function Used: sum() - Counts the number of incorrect submissions to ensure it is zero.
select username 
from user_submissions group by username 
having sum(case when points < 0 then 1 else 0 end) = 0;

-- Q13. Find The User Who Improved Their Performance The Most Over Time.
-- Learning: This query tracks users performance improvements by comparing their best and worst monthly scores, showing progress over time.
-- Function Used: extract() - Extracts the month from the timestamp, sum() - Calculates total monthly points, max() - Finds the highest monthly score, min() - Finds the lowest monthly score.
with user_performance as(
    select username, extract(month from submitted_at) as month, sum(points) as monthly_points 
    from user_submissions 
    group by username, month),

improvement as(
    select username, max(monthly_points) - min(monthly_points) AS improvement_score 
    from user_performance
    group by username)

select username, improvement_score from improvement
order by improvement_score desc limit 1;
