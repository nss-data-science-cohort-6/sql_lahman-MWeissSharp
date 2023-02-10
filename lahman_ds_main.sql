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

-- After finishing the above questions, here are some open-ended questions to consider.

-- **Open-ended questions**

-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.

-- 12. In this question, you will explore the connection between number of wins and attendance.

--     a. Does there appear to be any correlation between attendance at home games and number of wins?  
--     b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.


-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?