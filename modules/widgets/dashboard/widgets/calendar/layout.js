.import "lunar_calendar.js" as Lunar

var weekDays = [ // MONDAY IS THE FIRST DAY OF THE WEEK :HESRIGHTYOUKNOW:
    { day: 'Mo', today: 0 },
    { day: 'Tu', today: 0 },
    { day: 'We', today: 0 },
    { day: 'Th', today: 0 },
    { day: 'Fr', today: 0 },
    { day: 'Sa', today: 0 },
    { day: 'Su', today: 0 },
]

const CAN = ["Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý"];
const CHI = ["Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi"];

function getYearCanChi(lunarYear) {
    var canIdx = (lunarYear - 4) % 10;
    if (canIdx < 0) canIdx += 10;
    var chiIdx = (lunarYear - 4) % 12;
    if (chiIdx < 0) chiIdx += 12;
    return CAN[canIdx] + " " + CHI[chiIdx];
}

function checkLeapYear(year) {
    return (
        year % 400 == 0 ||
        (year % 4 == 0 && year % 100 != 0));
}

function getMonthDays(month, year) {
    const leapYear = checkLeapYear(year);
    if ((month <= 7 && month % 2 == 1) || (month >= 8 && month % 2 == 0)) return 31;
    if (month == 2 && leapYear) return 29;
    if (month == 2 && !leapYear) return 28;
    return 30;
}

function getNextMonthDays(month, year) {
    var nextMonth = month + 1;
    var nextYear = year;
    if (nextMonth == 13) {
        nextMonth = 1;
        nextYear++;
    }
    return getMonthDays(nextMonth, nextYear);
}

function getPrevMonthDays(month, year) {
    var prevMonth = month - 1;
    var prevYear = year;
    if (prevMonth == 0) {
        prevMonth = 12;
        prevYear--;
    }
    return getMonthDays(prevMonth, prevYear);
}

function getDateInXMonthsTime(x, baseDate) {
    var currentDate = baseDate || new Date(); // Get the current date
    if (x == 0) return currentDate; // If x is 0, return the current date

    var targetMonth = currentDate.getMonth() + x; // Calculate the target month
    var targetYear = currentDate.getFullYear(); // Get the current year

    // Adjust the year and month if necessary
    targetYear += Math.floor(targetMonth / 12);
    targetMonth = (targetMonth % 12 + 12) % 12;

    // Create a new date object with the target year and month
    var targetDate = new Date(targetYear, targetMonth, 1);

    // Set the day to the last day of the month to get the desired date
    // targetDate.setDate(0);

    return targetDate;
}

function getCalendarLayout(dateObject, highlight) {
    if (!dateObject) dateObject = new Date();
    const weekday = (dateObject.getDay() + 6) % 7; // MONDAY IS THE FIRST DAY OF THE WEEK
    const day = dateObject.getDate();
    const month = dateObject.getMonth() + 1;
    const year = dateObject.getFullYear();
    const weekdayOfMonthFirst = (weekday + 35 - (day - 1)) % 7;
    const daysInMonth = getMonthDays(month, year);
    const daysInNextMonth = getNextMonthDays(month, year);
    const daysInPrevMonth = getPrevMonthDays(month, year);

    // Fill
    var monthDiff = (weekdayOfMonthFirst == 0 ? 0 : -1);
    var toFill, dim;
    if(weekdayOfMonthFirst == 0) {
        toFill = 1;
        dim = daysInMonth;
    }
    else {
        toFill = (daysInPrevMonth - (weekdayOfMonthFirst - 1));
        dim = daysInPrevMonth;
    }
    var calendar = [...Array(6)].map(() => Array(7));
    var i = 0, j = 0;
    var currentWeekRow = -1;
    while (i < 6 && j < 7) {
        var cellMonth = month + monthDiff;
        var cellYear = year;
        if (cellMonth == 0) {
            cellMonth = 12;
            cellYear--;
        } else if (cellMonth == 13) {
            cellMonth = 1;
            cellYear++;
        }
        var cellDay = toFill;

        var lunarDayVal = 0;
        var lunarMonthVal = 0;
        var lunarYearVal = 0;
        var lunarLeapVal = 0;
        var lunarText = "";
        try {
            var lunarData = Lunar.convertSolar2Lunar(cellDay, cellMonth, cellYear, 7.0);
            lunarDayVal = lunarData[0];
            lunarMonthVal = lunarData[1];
            lunarYearVal = lunarData[2];
            lunarLeapVal = lunarData[3];

            if (lunarDayVal === 1) {
                lunarText = "1/" + lunarMonthVal + (lunarLeapVal ? "b" : "");
            } else {
                lunarText = lunarDayVal.toString();
            }
        } catch (err) {
            console.log("Error converting solar to lunar in layout.js:", err);
        }

        calendar[i][j] = {
            "day": toFill,
            "today": ((toFill == day && monthDiff == 0 && highlight) ? 1 : (
                monthDiff == 0 ? 0 :
                    -1
            )),
            "cellDay": cellDay,
            "cellMonth": cellMonth,
            "cellYear": cellYear,
            "lunarDay": lunarDayVal,
            "lunarMonth": lunarMonthVal,
            "lunarYear": lunarYearVal,
            "lunarLeap": lunarLeapVal,
            "lunarText": lunarText
        };
        if (toFill == day && monthDiff == 0 && highlight) {
            currentWeekRow = i;
        }
        // Increment
        toFill++;
        if (toFill > dim) { // Next month?
            monthDiff++;
            if (monthDiff == 0)
                dim = daysInMonth;
            else if (monthDiff == 1)
                dim = daysInNextMonth;
            toFill = 1;
        }
        // Next tile
        j++;
        if (j == 7) {
            j = 0;
            i++;
        }

    }
    return { calendar: calendar, currentWeekRow: currentWeekRow };
}
