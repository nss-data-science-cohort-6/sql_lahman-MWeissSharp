-- 1. Find all players in the database who played at Vanderbilt University. Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?
WITH vandy_players AS (
						SELECT DISTINCT playerid
						FROM collegeplaying 
							LEFT JOIN schools
							USING(schoolid)
						WHERE schoolid = 'vandy'
)
SELECT namefirst, 
	   namelast, 
	   SUM(salary)::numeric::money AS total_salary, 
	   COUNT(DISTINCT yearid) AS years_played
FROM people
	 INNER JOIN vandy_players
	 USING(playerid)
	 LEFT JOIN salaries
	 USING(playerid)
GROUP BY playerid, namefirst, namelast
ORDER BY total_salary DESC NULLS LAST;
-- David Price is the highest earning MLB player with $81,851,296.00 in combined salary

-- 2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.
SELECT CASE
			WHEN pos = 'OF' THEN 'Outifield'
			WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
			WHEN pos IN ('P', 'C') THEN 'Battery'
			ELSE 'other' END AS player_group,
		SUM(po) AS total_putouts
FROM fielding
WHERE yearid = 2016
GROUP BY player_group;
-- Battery 41,424 ; Infield 58,934 ; Outfield 29,560

-- 3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)
WITH year_bins AS (
			SELECT generate_series(1920, 2010, 10) AS begin_yr,
				   generate_series(1929, 2019, 10) AS end_yr)
SELECT begin_yr,
	   end_yr,
	   ROUND(SUM(so)::numeric / (SUM(g)/2), 2) AS so_per_game
FROM year_bins
	 LEFT JOIN teams
	 ON yearid >= begin_yr
	 AND yearid <= end_yr
GROUP BY begin_yr, end_yr
ORDER BY begin_yr;
-- steady increase with each increase 
WITH year_bins AS (
			SELECT generate_series(1920, 2010, 10) AS begin_yr,
				   generate_series(1929, 2019, 10) AS end_yr)
SELECT begin_yr,
	   end_yr,
	   ROUND(SUM(hr)::numeric / (SUM(g)/2), 2) AS hr_per_game
FROM year_bins
	 LEFT JOIN teams
	 ON yearid >= begin_yr
	 AND yearid <= end_yr
GROUP BY begin_yr, end_yr
ORDER BY begin_yr;
--Not quite as steady of an increase, but nonetheless trending upwards


-- 4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases. Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.
SELECT namefirst,
	   namelast,
	   sb AS successful_steals,
	   cs + sb AS total_steal_attempts,
	   ROUND(sb * 100.0 / (cs + sb), 2) AS successful_steal_percentage
FROM batting
	LEFT JOIN people
	USING(playerid)
WHERE yearid = 2016
	AND sb + cs >= 20
ORDER BY successful_steal_percentage DESC;
-- Chris Owings successfully stole 21 bases out of 23 attempts

-- 5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? 
SELECT *
FROM teams
WHERE wswin = 'N'
	AND yearid >= 1970
ORDER BY w DESC
LIMIT 1;
-- Seattle Mariners in 2001 with 116 wins

-- What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case. 
SELECT *
FROM teams
WHERE wswin = 'Y'
	AND yearid >= 1970
ORDER BY w
LIMIT 1;
-- LA Dodgers in 1981 with 63 wins, there was a player's strike

-- Then redo your query, excluding the problem year. 
SELECT *
FROM teams
WHERE wswin = 'Y'
	AND yearid >= 1970
	AND yearid != 1981
ORDER BY w
LIMIT 1;
-- St. Louis Cardinals in 2006 with 83 wins

-- How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?
WITH w_rank AS(	SELECT teamid,
			   		   name,
					   yearid,
					   RANK() OVER(PARTITION BY yearid ORDER BY w DESC)
				FROM teams
			  	WHERE yearid >= 1970),
	 ws_wins AS(SELECT teamid, yearid
				FROM teams
				WHERE wswin = 'Y'
					AND yearid >= 1970	)
SELECT COUNT(*) AS count_ws_max_w_teams,
	   ROUND(COUNT(*) * 100.0 / (2016-1969), 2) AS percent_ws_max_w_teams
FROM w_rank
	 INNER JOIN ws_wins 
	 USING(teamid, yearid)
WHERE rank = 1;
-- 12 times in this time frame, 25.53% of the time

-- An idea occurred to me:
WITH m_wins AS	(SELECT 
					yearid,
					MAX(w) AS max_w
				FROM teams
				WHERE yearid BETWEEN 1970 AND 2016
				GROUP BY yearid)
SELECT COUNT(CASE WHEN w = max_w THEN teamid END) AS max_w_ws_w,
	   ROUND(COUNT(CASE WHEN w = max_w THEN teamid END) * 100.0/ COUNT(DISTINCT yearid), 2) AS percent_max_w_ws_w
FROM teams
	INNER JOIN m_wins
	USING(yearid)
WHERE wswin='Y'
	AND yearid BETWEEN 1970 AND 2016;
--This is better, accounts for the year there was no World Series due to a strike so 12 and 26.09%

-- 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.
SELECT namefirst,
	   namelast,
	   yearid,
	   lgid,
	   name
FROM people
	 INNER JOIN awardsmanagers
	 USING(playerid)
	 INNER JOIN managers
	 USING(playerid, yearid, lgid)
	 INNER JOIN teams
	 USING(yearid, teamid, lgid)
WHERE (playerid, awardid) IN (SELECT playerid, awardid
								FROM awardsmanagers
								WHERE awardid = 'TSN Manager of the Year'
							  		AND lgid IN ('NL', 'AL')
								GROUP BY playerid, awardid
								HAVING COUNT(DISTINCT lgid) =2);

-- 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.
WITH sos AS	(SELECT playerid,
					   SUM(so) AS total_so
				FROM pitching
				WHERE yearid = 2016
			 		AND gs >= 10
				GROUP BY playerid),
	 salary_sum AS	(SELECT playerid,
							   SUM(salary) AS total_salary
						FROM salaries
						WHERE yearid = 2016
						GROUP BY playerid)
SELECT playerid,
	   total_so,
	   total_salary::numeric::money,
	   (total_salary / total_so)::numeric::money AS price_per_so
FROM sos
	 LEFT JOIN salary_sum
	 USING(playerid)
ORDER BY price_per_so DESC NULLS LAST;

-- 8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.
WITH high_hitters AS (SELECT playerid, SUM(h) AS total_hits
					  FROM batting
					  GROUP BY playerid
					  HAVING SUM(h) >= 3000),
	 hall_of_famers AS(SELECT playerid, yearid
					   FROM halloffame
					   WHERE inducted = 'Y')
SELECT namefirst,
	   namelast,
	   total_hits,
	   yearid
FROM high_hitters
	 INNER JOIN people
	 USING(playerid)
	 LEFT JOIN hall_of_famers
	 USING(playerid);

-- 9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.
WITH thousand_hitters AS 	(SELECT playerid, teamid, SUM(h) AS total_team_hits
							FROM batting
							GROUP BY playerid, teamid
							HAVING SUM(h) > 1000)
SELECT namefirst, namelast
FROM thousand_hitters
	 INNER JOIN people
	 USING(playerid)
GROUP BY playerid, namefirst, namelast
HAVING COUNT(*) > 1;

-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.
WITH yearly_hr AS (	SELECT playerid,
				   		   yearid,
				  		   SUM(hr) AS hr
				    FROM batting
				    GROUP BY playerid, yearid
				  ),
	top_hrs AS (	SELECT playerid,
						   MAX(hr) AS hr,
				 		   COUNT(yearid) AS years_played
					FROM yearly_hr
					GROUP BY playerid
					HAVING COUNT(yearid) >= 9)
SELECT namefirst || ' ' || namelast AS full_name,
	   hr
FROM top_hrs 
	 LEFT JOIN yearly_hr USING(playerid, hr)
	 INNER JOIN people
	 USING(playerid)
WHERE yearid = 2016
	AND hr > 0;
-- 9 players

-- After finishing the above questions, here are some open-ended questions to consider.

-- **Open-ended questions**

-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.
WITH wins_and_salaries AS	(SELECT
								teamid,
								yearid,
								w AS wins,
								DENSE_RANK() OVER(PARTITION BY yearid ORDER BY w DESC) AS win_rank,
								SUM(salary)::numeric AS team_salary,
								DENSE_RANK() OVER(PARTITION BY yearid ORDER BY SUM(salary) DESC) AS salary_rank,
							 	ROUND(w::decimal / AVG(g) * 100, 2) AS percent_wins,
	   							RANK() OVER(PARTITION BY yearid ORDER BY ROUND(w::decimal / AVG(g) * 100, 2) DESC) AS win_percent_rank
							FROM salaries
								INNER JOIN teams
								USING(teamid, yearid)
							WHERE yearid >= 2000
							GROUP BY teamid, yearid, w)
SELECT DISTINCT 
	yearid, 
	ROUND(CORR(wins, team_salary)OVER(PARTITION BY yearid)::numeric, 4) AS w_salary_corr,
	ROUND(CORR(win_rank, salary_rank)OVER(PARTITION BY yearid)::numeric, 4) AS wrank_salaryrank_corr,
	ROUND(CORR(win_percent_rank, salary_rank)OVER(PARTITION BY yearid)::numeric, 4) AS wpercentagerank_salaryrank_corr
FROM wins_and_salaries
ORDER BY yearid;
-- For most years, there is a weak positive correlation between wins and salary

-- 12. In this question, you will explore the connection between number of wins and attendance.

--     a. Does there appear to be any correlation between attendance at home games and number of wins?  
--Table below gives attendance and homegames for each team each year
SELECT DISTINCT team,
	   		 	year,
			    SUM(attendance) OVER(PARTITION BY team, year) AS homegame_total_attendance,
	  			SUM(games) OVER(PARTITION BY team, year) AS homegames
FROM homegames
ORDER BY year, team;
--Pulling in team name and wins
WITH hg AS	(SELECT DISTINCT team,
	   		 				 year,
			 				 SUM(attendance) OVER(PARTITION BY team, year) AS homegame_total_attendance,
	   		 				 SUM(games) OVER(PARTITION BY team, year) AS homegames
			 FROM homegames
			 ORDER BY year, team)
SELECT t.name,
	   hg.year,
	   hg.homegame_total_attendance,
	   hg.homegames,
	   ROUND(hg.homegame_total_attendance/hg.homegames, 0) AS homegame_attendance_per_game,
	   t.w AS wins,
	   t.g AS total_games
FROM hg LEFT JOIN teams AS t ON hg.team = t.teamid AND hg.year = t.yearid
ORDER BY hg.year, t.name;

--     b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.
--Data for teams with WS wins
--Using LEAD function for world series winners
SELECT *
FROM 	(WITH hg AS	(SELECT DISTINCT team,
									 year,
									 SUM(attendance) OVER(PARTITION BY team, year) AS homegame_total_attendance,
									 SUM(games) OVER(PARTITION BY team, year) AS homegames
					 FROM homegames)
		SELECT t.name,
			   hg.year AS wswin_year,
			   hg.homegame_total_attendance,
			   hg.homegames,
		 	   t.wswin,
			   ROUND(hg.homegame_total_attendance/hg.homegames, 0) AS homegame_attendance_per_game,
			   LEAD(hg.homegame_total_attendance, 1) OVER(PARTITION BY t.name ORDER BY t.yearid) AS ny_hg_total_attendance,
			   LEAD(hg.homegames, 1) OVER(PARTITION BY t.name ORDER BY t.yearid) AS ny_homegames,
			   LEAD(ROUND(hg.homegame_total_attendance/hg.homegames, 0), 1) OVER(PARTITION BY t.name ORDER BY t.yearid) AS ny_hg_attendance_per_game
		FROM hg INNER JOIN teams AS t ON hg.team = t.teamid AND hg.year = t.yearid) AS year_comparisons
WHERE wswin = 'Y'
ORDER BY wswin_year;
--Doing calculations on the attendance change
SELECT name,
	   year AS wswin_year,
	   (ny_hg_total_attendance - homegame_total_attendance) AS total_attendance_change,
	   ny_hg_attendance_per_game - homegame_attendance_per_game AS per_game_attendance_change,
	   ny_homegames - homegames AS hg_count_change
FROM 	(WITH hg AS	(SELECT DISTINCT team,
									 year,
									 SUM(attendance) OVER(PARTITION BY team, year) AS homegame_total_attendance,
									 SUM(games) OVER(PARTITION BY team, year) AS homegames
					 FROM homegames)
		SELECT t.name,
			   hg.year,
			   hg.homegame_total_attendance,
			   hg.homegames,
			   ROUND(hg.homegame_total_attendance/hg.homegames, 0) AS homegame_attendance_per_game,
			   t.wswin,
			   LEAD(hg.year, 1) OVER(PARTITION BY t.name ORDER BY t.yearid) AS next_year,
			   LEAD(hg.homegame_total_attendance, 1) OVER(PARTITION BY t.name ORDER BY t.yearid) AS ny_hg_total_attendance,
			   LEAD(hg.homegames, 1) OVER(PARTITION BY t.name ORDER BY t.yearid) AS ny_homegames,
			   LEAD(ROUND(hg.homegame_total_attendance/hg.homegames, 0), 1) OVER(PARTITION BY t.name ORDER BY t.yearid) AS ny_hg_attendance_per_game
		FROM hg INNER JOIN teams AS t ON hg.team = t.teamid AND hg.year = t.yearid) AS year_comparisons
WHERE wswin = 'Y'
ORDER BY wswin_year;
--AVG changes
SELECT ROUND(AVG(ny_hg_total_attendance - homegame_total_attendance), 0) AS avg_total_attendance_change,
	   ROUND(AVG(ny_hg_attendance_per_game - homegame_attendance_per_game), 0) AS avg_per_game_attendance_change
FROM 	(WITH hg AS	(SELECT DISTINCT team,
									 year,
									 SUM(attendance) OVER(PARTITION BY team, year) AS homegame_total_attendance,
									 SUM(games) OVER(PARTITION BY team, year) AS homegames
					 FROM homegames)
		SELECT t.name,
			   hg.year,
			   hg.homegame_total_attendance,
			   hg.homegames,
			   ROUND(hg.homegame_total_attendance/hg.homegames, 0) AS homegame_attendance_per_game,
			   t.wswin,
			   LEAD(hg.year, 1) OVER(PARTITION BY t.name ORDER BY t.yearid) AS next_year,
			   LEAD(hg.homegame_total_attendance, 1) OVER(PARTITION BY t.name ORDER BY t.yearid) AS ny_hg_total_attendance,
			   LEAD(hg.homegames, 1) OVER(PARTITION BY t.name ORDER BY t.yearid) AS ny_homegames,
			   LEAD(ROUND(hg.homegame_total_attendance/hg.homegames, 0), 1) OVER(PARTITION BY t.name ORDER BY t.yearid) AS ny_hg_attendance_per_game
		FROM hg INNER JOIN teams AS t ON hg.team = t.teamid AND hg.year = t.yearid) AS year_comparisons
WHERE wswin = 'Y';
--I'm not reproducing for the division/wild card winners here, but you would do the same thing, just adjust your WHERE statement accordingly

-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?
--Getting a list of all pitchers from the people table
SELECT playerid, namefirst, namelast, throws
FROM people
WHERE playerid IN
				(SELECT playerid
				 FROM pitching);

SELECT COUNT(DISTINCT playerid)
FROM people
WHERE playerid IN
				(SELECT playerid
				 FROM pitching);
--9302 pitchers
--Getting all entry options for the throws column
SELECT DISTINCT throws
FROM people
WHERE playerid IN
				(SELECT playerid
				 FROM pitching);
--R, L, null, and S are the options
--Getting counts for each option
SELECT 
	COUNT(CASE WHEN throws = 'R' THEN playerid END) AS r_handed_pitchers,
	COUNT(CASE WHEN throws = 'L' THEN playerid END) AS l_handed_pitchers,
	COUNT(CASE WHEN throws IS NULL THEN playerid END) AS unknown,
	COUNT(CASE WHEN throws = 'S' THEN playerid END) AS s_pitchers
FROM people
WHERE playerid IN
				(SELECT playerid
				 FROM pitching);
-- R=6605, L=2477, NULL=219, S=1
--Cy Young Award winners
SELECT playerid, namefirst, namelast, throws
FROM people
WHERE playerid IN
				(SELECT DISTINCT playerid
				FROM awardsplayers
				WHERE awardid = 'Cy Young Award');
--Counts for handedness for Cy Young Award winners (there are no null or S pitchers in this group)
SELECT 
	COUNT(CASE WHEN throws = 'R' THEN playerid END) AS r_handed_pitchers,
	COUNT(CASE WHEN throws = 'L' THEN playerid END) AS l_handed_pitchers
FROM people
WHERE playerid IN
				(SELECT playerid
				FROM awardsplayers
				WHERE awardid = 'Cy Young Award');
--53 right handed, 24 left handed

--Combining all pitcher info w/ Cy Young award info, award was first given in 1956, so limiting to those years
WITH all_pitchers AS (SELECT playerid,
					  namefirst,
					  namelast,
					  throws
					  FROM people
					  WHERE playerid IN
									(SELECT playerid
									 FROM pitching
									 WHERE yearid >=1956)),
	 cy_winners AS	(SELECT playerid, awardid
					 FROM awardsplayers
					 WHERE awardid = 'Cy Young Award')
SELECT namefirst, namelast, throws, awardid
FROM all_pitchers FULL JOIN cy_winners USING(playerid);
--Getting percentages
SELECT ROUND(r_handed_winners::decimal / r_handed_pitchers * 100, 2) AS percent_of_r_handed,
	   ROUND(l_handed_winners::decimal / l_handed_pitchers * 100, 2) AS percent_of_l_handed
FROM(WITH all_pitchers AS (SELECT playerid,
							  namefirst,
							  namelast,
							  throws
							  FROM people
							  WHERE playerid IN
											(SELECT playerid
											 FROM pitching
											 WHERE yearid >=1956)),
			 cy_winners AS	(SELECT DISTINCT(playerid), awardid
							 FROM awardsplayers
							 WHERE awardid = 'Cy Young Award')
		SELECT
			COUNT(CASE WHEN throws = 'R' THEN playerid END) AS r_handed_pitchers,
			COUNT(CASE WHEN throws = 'L' THEN playerid END) AS l_handed_pitchers,
			COUNT(CASE WHEN throws IS NULL THEN playerid END) AS unknown,
			COUNT(CASE WHEN throws = 'S' THEN playerid END) AS s_pitchers,
			COUNT(CASE WHEN throws = 'R' AND awardid = 'Cy Young Award' THEN playerid END) AS r_handed_winners,
			COUNT(CASE WHEN throws = 'L' AND awardid = 'Cy Young Award' THEN playerid END) AS l_handed_winners
		FROM all_pitchers LEFT JOIN cy_winners USING(playerid)) AS counts;
--1.32% of right handed pitchers since 1956 became Cy Young Award winners, 1.51% of left handed pitchers

--Hall of fame calculations
SELECT ROUND(r_handed_winners::decimal / r_handed_pitchers * 100, 2) AS percent_of_r_handed,
	   ROUND(l_handed_winners::decimal / l_handed_pitchers * 100, 2) AS percent_of_l_handed
FROM(WITH all_pitchers AS (SELECT playerid,
							  namefirst,
							  namelast,
							  throws
							  FROM people
							  WHERE playerid IN
											(SELECT playerid
											 FROM pitching)),
			 hof_winners AS	(SELECT playerid, yearid,
							 inducted AS hof_inductee
							 FROM halloffame
							 WHERE inducted = 'Y'
							 AND category = 'Player')
		SELECT
			COUNT(CASE WHEN throws = 'R' THEN playerid END) AS r_handed_pitchers,
			COUNT(CASE WHEN throws = 'L' THEN playerid END) AS l_handed_pitchers,
			COUNT(CASE WHEN throws IS NULL THEN playerid END) AS unknown,
			COUNT(CASE WHEN throws = 'S' THEN playerid END) AS s_pitchers,
			COUNT(CASE WHEN throws = 'R' AND hof_inductee = 'Y' THEN playerid END) AS r_handed_winners,
			COUNT(CASE WHEN throws = 'L' AND hof_inductee = 'Y' THEN playerid END) AS l_handed_winners
		FROM all_pitchers LEFT JOIN hof_winners USING(playerid)) AS counts;
		--1.09% of right handed pitchers have gone on to be inducted into the hall of fame, 0.89% of left handed pitchers 
