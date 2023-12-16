/*
    This file is part of the Lens distribution.

    https://github.com/senselogic/LENS

    Copyright (C) 2017 Eric Pelzer (ecstatic.coder@gmail.com)

    Lens is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3.

    Lens is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Lens.  If not, see <http://www.gnu.org/licenses/>.
*/

// -- IMPORTS

import std.algorithm;
import std.datetime;
import std.process;
import std.stdio;
import std.string;

// -- TYPES

struct CHANGE
{
    string
        Author;
    Date
        Date_;
    bool[ string ]
        HasAuthorDateMap;
    long
        AuthorDateCount,
        CommitCount,
        EditionCount;
}

// ~~

string GetAuthorDate(
    ref CHANGE change
    )
{
    return change.Author ~ '-' ~ change.Date_.toISOString()[ 0 .. 8 ];
}

// ~~

Date GetWeekDate(
    Date date
    )
{
    return date -= date.dayOfWeek.days;
}

// ~~

Date GetMonthDate(
    Date date
    )
{
    return Date( date.year, date.month, 1 );
}

// ~~

Date GetYearDate(
    Date date
    )
{
    return Date( date.year, 1, 1 );
}

// ~~

void AddChange(
    ref CHANGE[ string ][ Date ] change_map,
    Date date,
    string author,
    ref CHANGE change,
    long file_count
    )
{
    string
        author_date;

    author_date = change.GetAuthorDate();

    if ( date !in change_map )
    {
        change_map[ date ] = [ author: CHANGE.init ];
    }
    else if ( author !in change_map[ date ] )
    {
        change_map[ date ][ author ] = CHANGE.init;
    }

    change_map[ date ][ author ].Author = author;
    change_map[ date ][ author ].Date_ = date;
    change_map[ date ][ author ].HasAuthorDateMap[ author_date ] = true;
    change_map[ date ][ author ].AuthorDateCount = change_map[ date ][ author ].HasAuthorDateMap.length;
    change_map[ date ][ author ].CommitCount += 1;
    change_map[ date ][ author ].EditionCount += file_count;
}

// ~~

CHANGE GetTotalChange(
    CHANGE[ string ] change_by_author_map
    )
{
    CHANGE
        total_change;

    foreach ( author, change; change_by_author_map )
    {
        foreach ( author_date, has_autor_date; change.HasAuthorDateMap )
        {
            total_change.HasAuthorDateMap[ author_date ] = true;
        }

        total_change.AuthorDateCount = total_change.HasAuthorDateMap.length;
        total_change.CommitCount += change.CommitCount;
        total_change.EditionCount += change.EditionCount;
    }

    return total_change;
}

// ~~

CHANGE[ string ][ Date ] GetWeeklyChangeMap(
    CHANGE[ string ][ Date ] daily_change_map
    )
{
    CHANGE[ string ][ Date ]
        weekly_change_map;

    foreach ( date, change_by_author_map; daily_change_map )
    {
        foreach ( author, change; change_by_author_map )
        {
            AddChange( weekly_change_map, GetWeekDate( date ), author, change, change.EditionCount );
        }
    }

    return weekly_change_map;
}

// ~~

CHANGE[ string ][ Date ] GetMonthlyChangeMap(
    CHANGE[ string ][ Date ] daily_change_map
    )
{
    CHANGE[ string ][ Date ]
        monthly_change_map;

    foreach ( date, change_by_author_map; daily_change_map )
    {
        foreach ( author, change; change_by_author_map )
        {
            AddChange( monthly_change_map, GetMonthDate( date ), author, change, change.EditionCount );
        }
    }

    return monthly_change_map;
}

// ~~

CHANGE[ string ][ Date ] GetYearlyChangeMap(
    CHANGE[ string ][ Date ] daily_change_map
    )
{
    CHANGE[ string ][ Date ]
        monthly_change_map;

    foreach ( date, change_by_author_map; daily_change_map )
    {
        foreach ( author, change; change_by_author_map )
        {
            AddChange( monthly_change_map, GetYearDate( date ), author, change, change.EditionCount );
        }
    }

    return monthly_change_map;
}

// ~~

void PrintChangeMap(
    CHANGE[ string ][ Date ] change_map,
    string period
    )
{
    string[]
        author_array;
    Date[]
        date_array;
    CHANGE
        change,
        total_change;
    CHANGE[ string ]
        change_by_author_map;

    writeln( "By ", period );

    date_array = change_map.keys;
    sort( date_array );

    foreach ( date; date_array )
    {
        change_by_author_map = change_map[ date ];

        author_array = change_by_author_map.keys;
        sort( author_array );

        total_change = GetTotalChange( change_by_author_map );

        writeln( "    ", date, " (", total_change.AuthorDateCount, " author dates, ", total_change.CommitCount, " commits, ", total_change.EditionCount, " editions)" );

        foreach ( author; author_array )
        {
            change = change_by_author_map[ author ];

            writeln( "        ", author, " (", change.AuthorDateCount, " author dates, ", change.CommitCount, " commits, ", change.EditionCount, " editions)" );
        }
    }
}

// ~~

bool IsChangeFilePath(
    string file_path
    )
{
    foreach ( extension; [ ".dart", ".js", ".svelte" ] )
    {
        if ( file_path.endsWith( extension ) )
        {
            return true;
        }
    }

    return false;
}

// ~~

void ProcessCommitLog(
    string commit_log
    )
{
    string
        author;
    string[]
        part_array;
    Date
        date;
    CHANGE
        change;
    CHANGE[ string ][ Date ]
        daily_change_map;

    foreach ( line; commit_log.splitLines() )
    {
        if ( line.length > 0 )
        {
            if ( line.startsWith( ':' ) )
            {
                part_array = line.split( ' ' );

                author = part_array[ 1 ];
                date = Date.fromISOExtString( part_array[ 2 ] );
            }
            else
            {
                if ( IsChangeFilePath( line ) )
                {
                    change.Author = author;
                    change.Date_ = date;

                    AddChange( daily_change_map, date, author, change, 1 );
                }
            }
        }
    }

    PrintChangeMap( daily_change_map, "day" );
    PrintChangeMap( GetWeeklyChangeMap( daily_change_map ), "week" );
    PrintChangeMap( GetMonthlyChangeMap( daily_change_map ), "month" );
    PrintChangeMap( GetYearlyChangeMap( daily_change_map ), "year" );
}

// ~~

void main(
    )
{
    auto result = executeShell( "git log --pretty=format:\":%H %an %ad\" --date=short --name-only" );

    if ( result.status == 0 )
    {
        ProcessCommitLog( result.output );
    }
}
