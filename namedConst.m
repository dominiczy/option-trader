classdef namedConst
    %CONSTANTS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant)
        debug = 0;
        downloadVerbose = 0;
        warnings = 1;
        timerPeriodSmall = 1; % time between pages
        timerPeriodBig = 10; % time between stocks
        
        quandlKey = '15xuwisiLenq9w2iPygZ';
        alphaVantageKey = 'Y87O9E7CZIDW9QH6'
        
        oldestHistDate = '08-Aug-2017';
        histFolder = 'historicData\';
        posFolder = 'positions\';
        twWebPositions = 'dominicz positions from tastyworks';
        twDesktopPositions = 'tastyworks_positions_dominicz_';
        optionPageEnd = 'option';
        spreadEnd = 'spread';
        pricePageEnd = 'price';
        histEnd = 'hist_price';
        pageExtension = '.csv';
        dateTimeFormatShort = 'dd-MMM-yyyy';
        sdOneDelta = 0.16;
        sdTwoDelta = 0.025;

        defaultVolNrDays = 20; 
        minVolNrDays = 10;
        daysPerYear = 365;
        tradingDaysPerYear = 252; % used to annualize volatility
        plotCfgFile = 'C:\Users\domin\Documents\MATLAB\Add-Ons\Toolboxes\plt\code\screencfg.txt'
        agesAgo = datetime('1-Jan-1970')
        
        optionTableBaseName = 'optionTable';
        histTableBaseName = 'histTable';
        tableExtension = '.csv';
        dateStrFormat = 'dd-mm-yyyy_HH-MM-SS';
        dateStrFormatShort = 'dd-mm-yyyy';
        
        defaultContractSize = 100;
        commission = 1;
    end
    
    methods (Static)
        function cheatSheet = cheatSheet ()
%           Name, IVLevel, IVToHV, IVDirection, HVLevel, HVDirection, UnderlyingDirection
%           IntraMonthSkew, TermStructure, conditionComments, Setup,
%           TradingTime, RiskReward, Adjustments, Exit, Comments
            cheatSheet = containers.Map();
            cheatSheet('Vertical') = spreadType ('Vertical', '', {'bigger'}, {'stable' 'falling'}, '', '', {'up/down'}, '', '', 'Steep skew, narrow spread; less steep, wider', ...
                'Sell one and buy further out', [30 60], '', '', '60-70% of credit received', 'Directional');
            cheatSheet('Iron Condor') = spreadType ('Iron Condor', '', {'bigger'}, {'stable' 'falling'}, {'low'}, {'stable' 'falling'}, '', {'bit steep'}, '', 'In low vol: Skew not too steep (vol spike risk). Place in overbought month if any.', ...
                'Sell 10-11 delta call, buy next. Sell 10-12 delta put, buy next. In low vol, 10% of credit on units', [30 60], 'Calculate PoP and compare with credit received', ...
                'Max loss = profit target. At 1/3 first adjustment, at 2/3 second, at 3/3 exit. Upside: Kite, Ratio (in low vol). Downside: Ratio', '50-60% of credit received. Be out before day 30 of trade', 'Play high IV against ATR');
            cheatSheet('Iron Butterfly') = spreadType ('Iron Butterfly', {'low' 'mid'}, {'bigger'}, {'falling'}, '', '', '', {'flat'}, '', 'Buy put at 6-10% discount to normal relationship. Steep call curve. Place in high IV month. However term structure not too wide. Works better in low vol', ...
                'Sell OTM call+put. Wings at 1 SD for time in trade. Flatten delta with calls in tent. Use weeklies. In low vol, 1-2 units/10 flies', [10 30], 'Tighten or close if 10% profit hit/wings fall below 0.25. Risk/reward should be 1:1', ...
                'Exit if outside tent. Upside: tighten half, buy call (/spread). Downside: ratio, put spread', '5-10% in few days', 'Play current ATR against ATR for time of trade');
            cheatSheet('Calendar') = spreadType ('Calendar', {'low' 'mid'}, '', {'stable'}, {'very low' 'low'}, '', '', '', 'positive', 'Front month at 10% premium to normal relationship', ...
                'Sell ATM, buy in next month, close when relationship normalized. Any time can be traded if out of whack', [10 30], '', ...
                'Exit if breakeven at expiration hit, or at 10% loss', '5-10% in few days', 'Look at weighted vega');
            cheatSheet('Ratio') = spreadType ('Ratio', {'very low' 'low'}, '', '', '', '', {'up/down'}, {'flat'}, '', 'OTM 7-10% underpriced wrt normal relationship. Place in month with lowest IV', ...
                'Sell ATM, buy 2 OTM at credit. Close to exp is play on underlying move, far (>60 days) is vol trade (hedge)', [30 60], '', ...
                'Exit if not working (10% of margin). Add if conditions make it even better', '5-10% unless it is a runner', 'Sell overbought ATM IV with directional play'); 
        end
      
    end
    
end

