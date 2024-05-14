/* Create a library reference named proj pointing to the specified directory */
libname Project1 "/home/u63744822/sasuser.v94/fin557/Project1";


/* Import CSV file containing IPO data, specifying the dataset name and format */
PROC IMPORT DATAFILE='/home/u63744822/sasuser.v94/fin557/Project1/ipo_stock_2010_2018_v2.csv'
    OUT=IPOdata
    DBMS=CSV
    REPLACE;
    GETNAMES=YES;
    DATAROW=2;
RUN;

**************************************************;
*  1 Clean ipo_kaggle_data                       *;
**************************************************;

/* Display the structure and attributes of the imported IPO data */
PROC CONTENTS data=IPOdata;
RUN;

/* Print the first 10 observations of the IPO data to check the import results */
PROC PRINT data=IPOdata (obs=10);
RUN;

/* Frequency analysis on the Market column to check data consistency and missing values */
proc freq data=IPOdata;
tables Market / nocum nopercent missing;
run;

/* Descriptive statistics for financial metrics in the IPO data */
proc means data=IPOdata;
var Price Shares 'Offer Amount'n;
run;

/* Clean and prepare IPO data by renaming and reordering columns, and formatting values */
data Project1.ipo_kaggle_data_clean;

/* Keep original order of columns but ensure they are in a specific sequence */
retain Company_Name Sector Industry State Ticker Market IPO_Price IPO_Shares IPO_Offer_Amount IPO_Date IPO_Year;

/* Rename and reorder dataset columns */
set ipodata(rename=(
'Company Name'n = Company_Name
Symbol = Ticker
Price = IPO_Price
Shares = IPO_Shares
'Offer Amount'n = IPO_Offer_Amount
'Date Priced'n = IPO_Date
US_state = State
sector = Sector
industry = Industry
));

/* Format financial columns for clarity */
format IPO_Price dollar10.2 IPO_Shares comma10. IPO_Offer_Amount dollar20.2;

/* Simplify market names for consistency in analysis */
if Market in ('American Stock Exchange', 'NYSE MKT', 'New York Stock Exchange') then Market = 'NYSE';
else if Market in ('NASDAQ Capital', 'NASDAQ Global', 'NASDAQ Global Select', 'NASDAQ Global Market', 'NASDAQ Smallcap Market') then Market = 'NASDAQ';

/* Filter out records where State is missing */
if not missing(State);

/* Extract year from the IPO Date for easier time-based analysis */
IPO_Year = year(Year);

/* Drop all columns except those explicitly kept */
keep Company_Name Sector Industry State Ticker Market IPO_Price IPO_Shares IPO_Offer_Amount IPO_Date IPO_Year;
run;


/* Sort IPO data by year for chronological analysis */
proc sort data=Project1.ipo_kaggle_data_clean;
    by IPO_Year;
run;

/* Display sorted IPO data to confirm sorting and check data integrity */
proc print data=Project1.ipo_kaggle_data_clean;
    title "Sorted IPO Data by Year";
run;

**************************************************;
*  2 Clean stock_data                            *;
**************************************************;
/* Import stock data from CSV, specifying dataset attributes and format */
PROC IMPORT DATAFILE='/home/u63744822/sasuser.v94/fin557/Project1/stock_2008_2020.csv'
    OUT=stock_data
    DBMS=CSV
    REPLACE;
    GETNAMES=YES;
    DATAROW=2;
RUN;

/* Explore the structure of the newly imported stock data */
PROC CONTENTS data=stock_data;
RUN;

/* Print the first 10 observations of the stock data to check the import results */
PROC PRINT data=stock_data (obs=10);
RUN;

/* Prepare stock data by extracting date components and calculating additional metrics */
data stock_data;
    set stock_data;
    Year = year(date);
	Month = month(date);
	Day = day(date);
run;

/* Calculate abnormal return */
data stock_intermediate;
    set stock_data;
    where Year between 2008 and 2020 and not missing(Ticker);
    abnret = sum(RET, -vwretd); 
run;

/* Sorting the data by year and ticker */
proc sort data=stock_intermediate;
    by Ticker Year;
run;

/* Print the first 10 observations of the stock data */
PROC PRINT data=stock_intermediate (obs=10);
RUN;

/* Calculate yearly averages and other metrics for stock data */
data yearly_averages(keep=year ticker avg_PRC avg_VOL avg_abnret);
    set stock_intermediate;
    by ticker year;

    retain sum_prc sum_vol sum_abnret  count;

	/* Initialize sums and count at the start of each year for each ticker */
    if first.year then do;
        sum_prc = 0;
        sum_vol = 0;
        sum_abnret = 0;
        count = 0;
    end;
	
	/* Accumulate yearly data */
    sum_prc = sum_prc + PRC;
    sum_vol = sum_vol + VOL;
    sum_abnret = sum_abnret + abnret;
    count = count + 1;

	/* Calculate and output averages at the end of each year for each ticker */
    if last.year then do;
        avg_PRC = sum_prc / count;
        avg_VOL = sum_vol / count;
        avg_abnret = sum_abnret / count;
        output;   /* Output the averages for each group */
        count = 0;  /* Reset the count for the next group */
    end;

	/* Format average metrics for readability */
    format avg_PRC avg_VOL avg_abnret 8.2;
run;

/* Compute cumulative abnormal returns */
data Project1.cum_stock;
    set yearly_averages;
    by Ticker Year;

    if first.Ticker then Cum_AbnRet = 0; /* Reset cumulative sum at the start of each year for each ticker */

    Cum_AbnRet + avg_abnret; /* Shorthand for Cum_AbnRet = Cum_AbnRet + abnret */

    format Cum_AbnRet 7.4;

    /* Output the final day of each year for each ticker */
    if last.Year then output;

    keep Ticker Year avg_PRC avg_VOL avg_abnret Cum_AbnRet ;
run;

/* Print the first 10 observations of the stock data */
PROC PRINT data=Project1.cum_stock (obs=100);
title "Sorted Stock Data by Year";
RUN;

/* Print the first 10 observations of the stock data */
PROC PRINT data=Project1.cum_stock (obs=10);
title "Sorted stock Data by Year";
RUN;


**************************************************;
*  3 Merge IPO and Stock data                    *;
**************************************************;
PROC PRINT data= Project1.ipo_kaggle_data_clean (obs=10);
RUN;

PROC PRINT data=Project1.cum_stock (obs=10);
RUN;

/* Merge IPO and stock data based on Ticker and relevant year range */
proc sql;
    create table merged_data as
    select 
        i.Company_Name, 
        i.Sector, 
        i.Industry, 
        i.State, 
        i.Ticker, 
        i.Market, 
        i.IPO_Price, 
        i.IPO_Shares, 
        i.IPO_Offer_Amount, 
        i.IPO_Date, 
        i.IPO_Year,
        s.avg_PRC, 
        s.avg_VOL, 
        s.avg_abnret, 
        s.Cum_AbnRet,
        s.Year
    from Project1.ipo_kaggle_data_clean i
    left join Project1.cum_stock s
        on i.Ticker = s.Ticker
           and s.Year between i.IPO_Year and (i.IPO_Year + 5)
    order by i.Ticker, s.Year;
quit;

/* Save the merged data into a final dataset */
data Project1.final_merged_data;
    set merged_data;
run;

/* Print the first 10 observations of the merged data */
PROC PRINT data=Project1.final_merged_data (obs=10);
title "Merged Data by Ticker";
RUN;

**************************************************;
*  4 Data Analysis                               *;
**************************************************;

**************************************************;
*  4.1 Descriptive Statistics                    *;
**************************************************;

proc means data=Project1.final_merged_data2 N mean stddev min max;
  var IPO_Price avg_PRC avg_VOL avg_abnret Cum_AbnRet;
run;

**************************************************;
*  4.2 Analysis of Variance (ANOVA)              *;
**************************************************;
/* To conduct an analysis of variance (ANOVA) to determine if there are statistically significant differences in IPO metrics across different sectors or industries. */ 

proc sgplot data=Project1.final_merged_data2;   
vbox IPO_Price / category=Sector; 
run;

/* In the Anova test, it is evident that there is least price variation in communication sevices, consumer defensive & utilities sectors. */

**************************************************;
*  4.3 Top company in each sector with highest avg price at the time of IPO for the year 2015*;
**************************************************;
/* Step 1: Filter the data for IPOs in the year 2015 */
data ipo_2015;
    set Project1.final_merged_data2;
    where year(IPO_Date) = 2015;
run;

/* Step 2: Calculate the average price for each company within each sector */
proc means data=ipo_2015 noprint;
    class Sector Company_name;
    var avg_PRC;
    output out=avg_prices(drop=_type_ _freq_) mean=Avg_PRC;
run;

/* Step 3: Identify the company with the highest average price within each sector */
proc sort data=avg_prices;
    by Sector descending Avg_PRC;
run;

data top_companies_2015_avg;
    set avg_prices;
    by Sector;
    if first.Sector;
run;

/* Step 4: Display the top company in each sector along with its average price */
proc print data=top_companies_2015_avg;
    var Sector Company_Name Avg_PRC;
    title "Top Company in Each Sector with Highest Average Price (Year 2015)";
run;

data top_companies_2015_avg_no_first;
    set top_companies_2015_avg;
    if _N_ > 1; /* This will skip the first row */
run; 

data top_companies_2015_avg_updated;
    set top_companies_2015_avg_no_first;
    if Sector = "Consumer Defensive" then Company_Name = "OLLIE'S BARGAIN OUTLET HOLDINGS, INC";
run;

**************************************************;
*  4.4 Price of these company stocks after 5 years (2020)*;
**************************************************;
data top_companies_2020_avg;
    set Project1.final_merged_data2;
    where year = 2020
    /*and company_name in ('PENUMBRA INC', 'ENVIVA PARTNERS, LP', 'WINGSTOP INC.', 'GREEN PLAINS PARTNERS LP', 'HOULIHAN LOKEY, INC.', 'TRANSUNION', 'COMMUNITY HEALTHCARE TRUST INC', 'TELADOC HEALTH, INC.');*/
    and Ticker in ('PEN', 'EVA', 'WING', 'GPRE', 'HLI', 'TRU', 'CHCT', 'TDOC', 'OLLI');
    keep Sector Company_Name Avg_PRC;
run;

proc print data=top_companies_2020_avg;
    var Sector Company_Name Avg_PRC;
    title "Top Company in Each Sector with Highest Average Price (Year 2020)";
run;

**************************************************;
*  4.5 Top company and sector with highest percentage price change over 5 years (2015-2020)*;
**************************************************;
/* Merge the datasets based on Company_Name and Sector */
proc sql;
    create table price_comparison as
    select a.Company_Name,
           a.Sector,
           a.avg_PRC as Price_2015,
           b.Avg_PRC as Price_2020
    from top_companies_2015_avg_updated as a
    inner join top_companies_2020_avg as b
    on a.Company_Name = b.Company_Name
       and a.Sector = b.Sector;
quit;

/* Calculate the percentage change for each company */
data price_comparison;
    set price_comparison;
    if Price_2015 > 0 then Percent_Change = ((Price_2020 - Price_2015) / Price_2015) * 100;
    else Percent_Change = .; /* Assign missing value if Price_2015 is zero to avoid division by zero */
run;

/* Sort the data to see the companies with the highest percentage change */
proc sort data=price_comparison;
    by descending Percent_Change;
run;

/* Print the result */
proc print data=price_comparison;
    var Company_Name Sector Price_2015 Price_2020 Percent_Change;
    title "Percentage Price Change from 2015 to 2020 for Top Companies";
run;
