-- 1. Find the Department Where the Third Highest GPA is Greater Than the Overall Average GPA
WITH DepartmentRankedGPA AS
    (SELECT department_id,
            student_id,
            gpa,
            DENSE_RANK() OVER (PARTITION BY department_id
                               ORDER BY gpa DESC) AS rank
     FROM students),
     OverallAverageGPA AS
    (SELECT AVG(gpa) AS overall_avg
     FROM students)
SELECT d.department_id
FROM DepartmentRankedGPA d
JOIN OverallAverageGPA o ON d.gpa > o.overall_avg
WHERE d.rank = 3;

-- 2. Find the Course with the Most Enrollments Each Year
WITH YearlyEnrollments AS
    (SELECT course_id,
            year,
            COUNT(student_id) AS enrollments,
            RANK() OVER (PARTITION BY year
                         ORDER BY COUNT(student_id) DESC) AS rank
     FROM enrollments
     GROUP BY course_id,
              year)
SELECT course_id,
       year,
       enrollments
FROM YearlyEnrollments
WHERE rank = 1;

-- 3. Find the Faculty Members Who Teach the Most Students But Have the Lowest Average Student Performance
WITH FacultyStats AS
    (SELECT faculty_id,
            COUNT(student_id) AS student_count,
            AVG(grade) AS avg_grade
     FROM enrollments
     JOIN courses ON enrollments.course_id = courses.course_id
     GROUP BY faculty_id),
     RankedFaculty AS
    (SELECT faculty_id,
            student_count,
            avg_grade,
            RANK() OVER (
                         ORDER BY student_count DESC) AS high_students,
                        RANK() OVER (
                                     ORDER BY avg_grade ASC) AS low_performance
     FROM FacultyStats)
SELECT faculty_id,
       student_count,
       avg_grade
FROM RankedFaculty
WHERE high_students = 1
    AND low_performance = 1;

-- 4. Find the Students Who Took More Than the Average Number of Courses but Scored Below the Median GPA
WITH StudentCourseCount AS
    (SELECT student_id,
            COUNT(course_id) AS total_courses
     FROM enrollments
     GROUP BY student_id),
     AverageCourses AS
    (SELECT AVG(total_courses) AS avg_courses
     FROM StudentCourseCount),
     MedianGPA AS
    (SELECT PERCENTILE_CONT(0.5) WITHIN
     GROUP (
            ORDER BY gpa) AS median_gpa
     FROM students)
SELECT s.student_id,
       s.gpa,
       sc.total_courses
FROM students s
JOIN StudentCourseCount sc ON s.student_id = sc.student_id
JOIN AverageCourses ac ON sc.total_courses > ac.avg_courses
JOIN MedianGPA mg ON s.gpa < mg.median_gpa;

-- 5. Identify the Departments Where Dropout Rates Have Increased for Three Consecutive Years
WITH DropoutTrends AS
    (SELECT department_id,
            year,
            COUNT(CASE
                      WHEN status = 'Dropped Out' THEN 1
                  END) * 1.0 / COUNT(*) AS dropout_rate,
            LAG(COUNT(CASE
                          WHEN status = 'Dropped Out' THEN 1
                      END) * 1.0 / COUNT(*), 1) OVER (PARTITION BY department_id
                                                      ORDER BY year) AS prev_year,
                                                     LAG(COUNT(CASE
                                                                   WHEN status = 'Dropped Out' THEN 1
                                                               END) * 1.0 / COUNT(*), 2) OVER (PARTITION BY department_id
                                                                                               ORDER BY year) AS two_years_ago
     FROM students
     GROUP BY department_id,
              year)
SELECT department_id
FROM DropoutTrends
WHERE dropout_rate > prev_year
    AND prev_year > two_years_ago;

