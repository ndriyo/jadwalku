begin tran;
SET NOCOUNT ON;

-------------------------------------
-- 1. Insert a School (Lazuardi)
-------------------------------------
DECLARE @SchoolID UNIQUEIDENTIFIER = NEWID();

INSERT INTO Schools (SchoolID, Name, Address, ContactNumber, Logo, CreatedAt, UpdatedAt)
VALUES (
    @SchoolID,
    'Lazuardi',
    'Jl. Pendidikan No.1, Jakarta, Indonesia',
    '+62-21-1234567',
    NULL,
    SYSUTCDATETIME(),
    SYSUTCDATETIME()
);

-------------------------------------
-- 2. Insert Grades (1 to 6)
-------------------------------------
-- We'll store the GradeIDs in a table variable for reference
DECLARE @Grades TABLE (GradeLevel INT, GradeID UNIQUEIDENTIFIER);

INSERT INTO @Grades (GradeLevel, GradeID)
VALUES (1, NEWID()), (2, NEWID()), (3, NEWID()), (4, NEWID()), (5, NEWID()), (6, NEWID());

INSERT INTO Grades (GradeID, SchoolID, GradeLevel, Description)
SELECT GradeID, @SchoolID, GradeLevel, 'Grade ' + CAST(GradeLevel AS NVARCHAR(10))
FROM @Grades;

-------------------------------------
-- 3. Insert Academic Period (2024S1)
-------------------------------------
DECLARE @AcademicPeriodID UNIQUEIDENTIFIER = NEWID();

INSERT INTO AcademicPeriods (AcademicPeriodID, SchoolID, Name, StartDate, EndDate)
VALUES (
    @AcademicPeriodID,
    @SchoolID,
    '2024S1',
    '2024-07-14',
    '2025-06-15'
);

-------------------------------------
-- 4. Insert Classes for Grades 1 to 6
-- Each grade has two classes: {Grade}A and {Grade}B (e.g., 1A, 1B, ... 6A, 6B)
-------------------------------------
DECLARE @Classes TABLE (ClassID UNIQUEIDENTIFIER, GradeLevel INT, Name NVARCHAR(10));

WITH ClassGen AS (
    SELECT GradeLevel, ClassSuffix
    FROM @Grades CROSS JOIN (VALUES ('A'),('B')) AS S(ClassSuffix)
)
INSERT INTO @Classes (ClassID, GradeLevel, Name)
SELECT NEWID(), GradeLevel, CAST(GradeLevel AS NVARCHAR(10)) + ClassSuffix
FROM ClassGen;

INSERT INTO Classes (ClassID, GradeID, AcademicPeriodID, Name, Description)
SELECT 
    C.ClassID,
    G.GradeID,
    @AcademicPeriodID,
    C.Name,
    'Class ' + C.Name
FROM @Classes C
JOIN @Grades G ON C.GradeLevel = G.GradeLevel;

-------------------------------------
-- 5. Insert 24 Teachers (and corresponding Users)
-------------------------------------
DECLARE @TeacherNames TABLE (FirstName NVARCHAR(100));
INSERT INTO @TeacherNames VALUES
('Budi'),('Iwan'),('Agus'),('Rina'),('Sari'),('Indah'),('Wati'),('Nur'),('Lina'),('Sri'),
('Dedi'),('Hasan'),('Rizal'),('Roni'),('Yanti'),('Cahyo'),('Dewi'),('Endang'),('Tono'),
('Joko'),('Adi'),('Putri'),('Dian'),('Fitri');

DECLARE @Count INT = 1;
DECLARE @TotalTeachers INT = 24;

WHILE @Count <= @TotalTeachers
BEGIN
    DECLARE @TName NVARCHAR(100);
    WITH TN AS (SELECT FirstName, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RN FROM @TeacherNames)
    SELECT @TName = FirstName FROM TN WHERE RN = @Count;

    DECLARE @UserID UNIQUEIDENTIFIER = NEWID();
    INSERT INTO Users (UserID, Email, PasswordHash, FirstName, LastName, Role, CreatedAt, UpdatedAt)
    VALUES (
        @UserID,
        @TName + CAST(@Count AS NVARCHAR(10)) + '@lazuardi.sch.id',
        'hashedpassword',
        @TName,
        'Guru',
        'Teacher',
        SYSUTCDATETIME(),
        SYSUTCDATETIME()
    );

    INSERT INTO Teachers (TeacherID, ContactNumber, SubjectsTaught)
    VALUES (
        @UserID,
        '+62-812-0000' + RIGHT('000' + CAST(@Count AS NVARCHAR(3)),3),
        'Multiple Subjects'
    );

    SET @Count += 1;
END;

-------------------------------------
-- 6. Insert 240 Students with Indonesian names
-- Distribute evenly among the 12 classes (Grades 1-6, each with A and B)
-- That means 240 / 12 = 20 students per class
-------------------------------------
DECLARE @ClassIDs TABLE (RowNum INT, ClassID UNIQUEIDENTIFIER);
WITH CTE_Classes AS (
    SELECT ClassID, ROW_NUMBER() OVER (ORDER BY Name) AS RN
    FROM Classes
    WHERE AcademicPeriodID = @AcademicPeriodID
)
INSERT INTO @ClassIDs (RowNum, ClassID)
SELECT RN, ClassID FROM CTE_Classes;

-- We'll use 10 first names and 10 last names to generate 100 combos and loop through them
DECLARE @FirstNames TABLE (Name NVARCHAR(100));
INSERT INTO @FirstNames VALUES 
('Rudi'),('Agus'),('Budi'),('Siti'),('Wati'),
('Dewi'),('Fitri'),('Sari'),('Dian'),('Rina');

DECLARE @LastNames TABLE (Name NVARCHAR(100));
INSERT INTO @LastNames VALUES 
('Susanto'),('Pratama'),('Lestari'),('Wibowo'),('Hartono'),
('Putri'),('Anggraini'),('Mahendra'),('Yusuf'),('Hasan');

DECLARE @StudentCount INT = 1;
DECLARE @TotalStudents INT = 240;

WHILE @StudentCount <= @TotalStudents
BEGIN
    -- Determine class: 20 students per class
    DECLARE @ClassIndex INT = ((@StudentCount - 1) / 20) + 1; 
    DECLARE @SelectedClassID UNIQUEIDENTIFIER;
    SELECT @SelectedClassID = ClassID FROM @ClassIDs WHERE RowNum = @ClassIndex;

    -- Name combination
    DECLARE @FIndex INT = ((@StudentCount - 1) % 100) / 10 + 1; 
    DECLARE @LIndex INT = ((@StudentCount - 1) % 10) + 1;

    DECLARE @StuFirstName NVARCHAR(100);
    DECLARE @StuLastName NVARCHAR(100);

    WITH FN AS (SELECT Name, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RN FROM @FirstNames),
         LN AS (SELECT Name, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RN FROM @LastNames)
    SELECT @StuFirstName = FN.Name, @StuLastName = LN.Name
    FROM FN, LN
    WHERE FN.RN = @FIndex
      AND LN.RN = @LIndex;

    DECLARE @StudentID UNIQUEIDENTIFIER = NEWID();
    INSERT INTO Students (StudentID, FirstName, LastName, ContactNumber, Email, ClassID, EnrollmentStatus, CreatedAt, UpdatedAt)
    VALUES (
        @StudentID,
        @StuFirstName,
        @StuLastName,
        '+62-813-0000' + RIGHT('000' + CAST(@StudentCount AS NVARCHAR(3)),3),
        'student' + CAST(@StudentCount AS NVARCHAR(10)) + '@lazuardi.sch.id',
        @SelectedClassID,
        'Enrolled',
        SYSUTCDATETIME(),
        SYSUTCDATETIME()
    );

    SET @StudentCount += 1;
END;

-------------------------------------
-- 7. Insert 240 Parents with Indonesian names
-- Each parent is also a user (Role='Parent')
-------------------------------------
DECLARE @ParentCount INT = 1;
DECLARE @TotalParents INT = 240;

WHILE @ParentCount <= @TotalParents
BEGIN
    SET @FIndex = ((@ParentCount - 1) % 100) / 10 + 1; 
    SET @LIndex = ((@ParentCount - 1) % 10) + 1;

    DECLARE @ParFirstName NVARCHAR(100);
    DECLARE @ParLastName NVARCHAR(100);

    WITH FN AS (SELECT Name, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RN FROM @FirstNames),
         LN AS (SELECT Name, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RN FROM @LastNames)
    SELECT @ParFirstName = FN.Name, @ParLastName = LN.Name
    FROM FN, LN
    WHERE FN.RN = @FIndex
      AND LN.RN = @LIndex;

    DECLARE @ParentUserID UNIQUEIDENTIFIER = NEWID();
    INSERT INTO Users (UserID, Email, PasswordHash, FirstName, LastName, Role, CreatedAt, UpdatedAt)
    VALUES (
        @ParentUserID,
        'parent' + CAST(@ParentCount AS NVARCHAR(10)) + '@lazuardi.sch.id',
        'hashedpassword',
        @ParFirstName,
        @ParLastName,
        'Parent',
        SYSUTCDATETIME(),
        SYSUTCDATETIME()
    );

    INSERT INTO Parents (ParentID, ContactNumber, Address)
    VALUES (
        @ParentUserID,
        '+62-814-0000' + RIGHT('000' + CAST(@ParentCount AS NVARCHAR(3)),3),
        'Jl. Keluarga No.' + CAST(@ParentCount AS NVARCHAR(3)) + ', Jakarta, Indonesia'
    );

    SET @ParentCount += 1;
END;

SET NOCOUNT ON;

-------------------------------------
-- 8. Add Teacher Assignments
-------------------------------------
-- We'll assume that Teachers and Classes have already been populated.

-- Retrieve Teachers ordered by their Email (from Users) to ensure a stable ordering
WITH OrderedTeachers AS (
    SELECT T.TeacherID, U.Email,
           ROW_NUMBER() OVER (ORDER BY U.Email) AS TeacherRowNum
    FROM Teachers T
    JOIN Users U ON T.TeacherID = U.UserID
)
SELECT * INTO #OrderedTeachers FROM OrderedTeachers;

-- Retrieve Classes ordered by Name (A stable ordering of classes)
WITH OrderedClasses AS (
    SELECT ClassID, Name,
           ROW_NUMBER() OVER (ORDER BY Name) AS ClassRowNum
    FROM Classes
)
SELECT * INTO #OrderedClasses FROM OrderedClasses;

-- Suppose we have 12 classes and 24 teachers.
-- We will assign 2 teachers per class.
-- If there are more or fewer classes/teachers, adjust the logic accordingly.

DECLARE @TotalClasses INT = (SELECT COUNT(*) FROM #OrderedClasses);
DECLARE @TeachersPerClass INT = 2; -- Adjust as needed

DECLARE @i INT = 1;
WHILE @i <= @TotalClasses
BEGIN
    DECLARE @ClassID UNIQUEIDENTIFIER;
    SELECT @ClassID = ClassID FROM #OrderedClasses WHERE ClassRowNum = @i;

    DECLARE @StartTeacherRow INT = (@i - 1) * @TeachersPerClass + 1; 
    DECLARE @EndTeacherRow INT = @i * @TeachersPerClass;

    -- Insert TeacherAssignments for each teacher in the range
    ;WITH TeacherRange AS (
        SELECT TeacherID
        FROM #OrderedTeachers
        WHERE TeacherRowNum BETWEEN @StartTeacherRow AND @EndTeacherRow
    )
    INSERT INTO TeacherAssignments (TeacherAssignmentID, TeacherID, ClassID, AssignedAt)
    SELECT NEWID(), TeacherID, @ClassID, SYSUTCDATETIME()
    FROM TeacherRange;

    SET @i += 1;
END

DROP TABLE #OrderedTeachers;
DROP TABLE #OrderedClasses;

SELECT 'Sample data insertion completed successfully.' AS Result;

commit tran;