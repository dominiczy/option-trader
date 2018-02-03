function ExpiryFri = getExpiryFri( month )
%Finds the relevant expiration Friday for the given month(s)
%Input "month" is a date during that month, for example "10-Oct-2012"
%Input can be an array of dates, in which case output is an array
%Output is a date, in datenum format

for i=1:length(month)
    
dv=datevec(month(i));
dv(3)=1; %set the date to the 1st of the month

day=weekday(datenum(dv)); %what day of the week is the 1st?  6 = Friday

switch day
    case 1
        Exp=20; % Expiry Friday will be on the 20th
    case 2
        Exp=19; 
    case 3
        Exp=18;
    case 4
        Exp=17;
    case 5
        Exp=16;
    case 6
        Exp=15;
    case 7
        Exp=21;
end %switch

dv(3)=Exp; %set the day equal to the expiry day
ExpiryFri(i)=datenum(dv);
end %for
end %function

