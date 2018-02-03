classdef spreadPlot < plotObj
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        xVarOpt = {'Price Underlying' 'Volatility chosen option' 'Days till exp near'}; 
        priceMid;
        priceMin;
        priceMax;
        daysTillExpMin;
        stdDevs = spreadPlot.stdDevsDefault;
        spread;
        currentXVar = 1;
     end
    
    properties (Constant)
       ptsOpt = 20*[1 2 4 8 16];
       defaultPts = 3;    
       stdDevsDefault = 3;
    end
    
    methods
        function obj = spreadPlot(spread, varargin)
            fprintf('Constructing spreadPlot.\n')
            obj = obj@plotObj(spread.stock, varargin{:});
            obj.spread = spread;
            obj.lbx = 'Selected X variable';  % this should depend on selected x axis
            obj.lby = {'Profit/Loss' [blanks(70) 'Greeks']};
            obj.rightStart = 8;
            obj.traceIDs = {'Breakeven' 'Act theo' 'Act mid' '+comm' 'PL' 'hist SD till near exp' 'IV chosen option' 'Delta' 'Gamma' 'Theta' 'Vega' 'Act Delta' 'Act Gamma' 'Act Theta' 'Act Vega'}; % PL slow uses one point and calculates using optstocksensbybls, Current shows current spread price
            
            if nargin > 0
                obj.setVars();
                obj.createPlot();
            end
        end
        
        function setVars (obj)
            obj.popupBottomLeftPosition = [.160 .710 .100 .200];
           
            obj.priceMid = obj.stock.getPrice1dVar('last', obj.timestamp);
            sigma = obj.stock.getPrice1dVar(['SD' num2str(namedConst.defaultVolNrDays)], obj.timestamp);
            obj.priceMin = obj.priceMid - obj.stdDevs * (sigma * obj.priceMid); 
            obj.priceMax = obj.priceMid + obj.stdDevs * (sigma * obj.priceMid);
            
            figName = strjoin(obj.spread.legs, '; ');
            obj.figName = join([string(obj.stock.symbol), figName], ': ');
        end
        
        % also enable plotting of intermarket spreads!!
        function createPlot (obj)
            fprintf('Executing %s: createPlot.\n', class(obj))
            
            S.tr = obj.newPlt();
                                    
            % add boxes for things like current price, current vol etc
            S.xVar = plt('pop', obj.popupTopLeftPosition , obj.xVarOpt,'callbk',@obj.clb,'swap');
            S.pts = plt('pop', obj.popupBottomLeftPosition, obj.ptsOpt,'callbk',@obj.clb, 'index', spreadPlot.defaultPts,'label','Points:', 'hide');
            
            
            S.IVOption = plt('pop', obj.popupTopRightPosition, obj.spread.legs,'callbk',@obj.clb, 'index', 1,'label','Use IV for option:', 'hide');

            S.priceStock  = plt('slider', obj.sliderLeftPosition, [obj.priceMid obj.priceMin obj.priceMax],'Price stock', @obj.clb, '%4W %4W %4W');
            % separate vol slider for each exp date,
            % set to corresponding vol from optionTable
            [SDs, spreadTable] = obj.spread.getTableVar('SD', obj.timestamp);
            expDates = spreadTable.expDate;
            uniqueExpDates = unique (expDates);

            volatility = obj.stock.getPrice2dVar(['SD' num2str(namedConst.defaultVolNrDays)], obj.timestamp);
            avgIVs = spreadTable.avgIV;
            % add label with spread legs
            for dateNr = 1:numel(uniqueExpDates)
                indicesDate = find(expDates == uniqueExpDates(dateNr));
                indexDate = indicesDate(1);
                volMid = SDs(indexDate);
                volMin = min(volatility);
                volMax = max(volatility);
                % here min IV for date is used as slider controls the lower
                % one
                IVs = obj.spread.getIVs (obj.timestamp);
                spreadExpDateIV = min(IVs(indicesDate));
                expDateIV = avgIVs(indexDate);
                if dateNr == 1
                    volPos = obj.sliderLeftMidPosition;
                else
                    volPos = obj.sliderMidPosition;
                end
                expDate = uniqueExpDates(dateNr);
                volLabel = prin('Vol0 %s, Realized %4W, Avg Implied %4W',  datestr(expDate), volMid, expDateIV);
                S.vol(dateNr) = plt('slider', volPos, [spreadExpDateIV volMin volMax], volLabel, @obj.clb, '%4W %4W %4W');
            end
            txtPos = obj.textUnderLegendPosition;

            S.volText = text(txtPos(1), txtPos(2),prin('Vol'),'units','norm','horiz','center','color',[.2 .6 1]);
            txtPos = obj.textBottomLeftPosition;
            S.greekText = text(txtPos(1), txtPos(2),prin('Greeks'),'units','norm','horiz','center','color',[.2 .6 1]);

            obj.daysTillExpMin = datenum(expDates(1)) - datenum(obj.stock.getTimestamp(obj.timestamp));
            S.days  = plt('slider', obj.sliderRightMidPosition, [obj.daysTillExpMin 0.1 obj.daysTillExpMin], ['Days till exp (' datestr(datenum(obj.stock.getTimestamp(obj.timestamp) + obj.daysTillExpMin),namedConst.dateStrFormatShort) ')'],@obj.clb, 2);       
            txtPos = obj.textTopRightPosition;
            S.daysText = text(txtPos(1), txtPos(2),'','units','norm','horiz','center','color',[.2 .6 1]);
			ask = obj.spread.getAsk(obj.timestamp);
			bid = obj.spread.getBid(obj.timestamp);
			mid = obj.spread.getMid(obj.timestamp);
            S.spreadPrice  = plt('slider', obj.sliderRightPosition, [mid min(bid, ask) max(bid, ask)],'Spread paid price', @obj.clb, '%5W %5W %5W');
            set(gcf, 'user', S);
            obj.clb();    % initialize plot
        end
        
        function clb(obj) % callback function for all objects
            S = get(gcf, 'user'); % retrieve config
            % read back popups
            xVar = plt('pop', S.xVar);
            pts = str2num(get(S.pts, 'string'));
            spreadPrice = plt('slider', S.spreadPrice);
            whichIV = plt('pop', S.IVOption);
            % read back sliders for vol and time and price
            spreadTable = obj.spread.getTable(obj.timestamp);
            expDates = spreadTable.expDate;
            uniqueExpDates = unique (expDates);
            daysTillExpNearNow = datenum(uniqueExpDates(1)) - datenum(obj.stock.getTimestamp(obj.timestamp));
            daysTillExpNear = plt('slider', S.days);
            IVs = obj.spread.getIVs (obj.timestamp);
            vol = zeros(numel(expDates),1);
            % FIXME need vol slider for each individual option
            for dateNr = 1:numel(uniqueExpDates)
                dateIndices = find(expDates == uniqueExpDates(dateNr));
                IVsDate = IVs (dateIndices);
                IVsDateRel = IVsDate / min(IVsDate);
                vol(dateIndices,1) = IVsDateRel * plt('slider', S.vol(dateNr)); 
            end
            price = plt('slider', S.priceStock);
            
            if xVar == 1
                % x is price Underlying 
                % make price slider invisible
                plt('slider', S.priceStock, 'visOFF');
                plt('slider', S.days, 'visON');
                for dateNr = 1:numel(uniqueExpDates)
                    plt('slider', S.vol(dateNr), 'visON');
                end
                price = linspace(obj.priceMin, obj.priceMax, pts); % x axis data
                price = price(price>0);
                X = price;

                set(S.daysText,'string',['View: '  datestr(datenum(uniqueExpDates(1)) - daysTillExpNear, namedConst.dateStrFormatShort)]);
            elseif xVar == 2
                % make vol sliders invisible
                for dateNr = 1:numel(uniqueExpDates)
                    plt('slider', S.vol(dateNr), 'visOFF');
                end
                plt('slider', S.days, 'visON');
                plt('slider', S.priceStock, 'visON');
                volatility = obj.stock.getPrice2dVar(['SD' num2str(namedConst.defaultVolNrDays)], obj.timestamp);
                volMin = min(volatility);
                volMax = max(volatility);
                vol = zeros(numel(expDates), pts);  
                % calc relationship of IVs
                IVsRel = IVs / IVs(whichIV);
                vol = IVsRel * linspace(volMin, volMax, pts); % x axis data
%                 for i = 1:numel(expDates)
                    % FIXME need options for the relationship between both vols
                    % if there are more
%                     volWeight = sqrt(obj.daysFromNow(expDate(1)) ./ obj.daysFromNow(expDate(i)));
%                     volWeight = 1;
%                     vol(i,:) = volWeight * linspace(volMin, volMax, pts); % x axis data
%                 end 
                X = vol(whichIV,:);
            elseif xVar == 3
                % x is time
                % make price slider visible
                plt('slider', S.priceStock, 'visON');
                for dateNr = 1:numel(uniqueExpDates)
                    plt('slider', S.vol(dateNr), 'visON');
                end
                % make time slider invisible
                plt('slider', S.days, 'visOFF');
                daysTillExpNear = linspace(0.1, daysTillExpNearNow, pts); % x axis data
                X = daysTillExpNear;
            end
            
            % call function that calculates P/L
            [delta, gamma, theta, vega, theo] = obj.spread.getSensIf (price, vol, daysTillExpNear, obj.timestamp);
            PL = theo - spreadPrice;
            set(S.tr(5), 'x', X, 'y', PL, 'LineWidth', 1.5);
            % right y axis (greeks)           
            set(S.tr(8), 'x', X, 'y', delta);
            set(S.tr(9), 'x', X, 'y', gamma);
            set(S.tr(10), 'x', X, 'y', theta);
            set(S.tr(11), 'x', X, 'y', vega);
            
            % these are implied rather than based on realized vol
            [deltaAct, gammaAct, vegaAct, thetaAct, theoAct] = obj.spread.getSens(obj.timestamp);
            lastPrice = obj.stock.getPrice1dVar('last', obj.timestamp);
            set(S.tr(12), 'x', lastPrice, 'y', deltaAct, 'Marker', '*', 'MarkerSize', 5);
            set(S.tr(13), 'x', lastPrice, 'y', gammaAct, 'Marker', '*', 'MarkerSize', 5);
            set(S.tr(14), 'x', lastPrice, 'y', thetaAct, 'Marker', '*', 'MarkerSize', 5);
            set(S.tr(15), 'x', lastPrice, 'y', vegaAct, 'Marker', '*', 'MarkerSize', 5);
            greeks = sprintf("Delta %3.3f, Gamma %3.3f, Theta %3.3f, Vega %3.3f, Theo %3.3f", deltaAct, gammaAct, thetaAct, vegaAct, theoAct);
            set(S.greekText,'string', greeks);
            
            putQuantities = obj.spread.getTableVar('putQuantity', obj.timestamp);
            if putQuantities(whichIV) ~= 0
                IVs = obj.spread.getTableVar('putIV', obj.timestamp);
            else
                IVs = obj.spread.getTableVar('callIV', obj.timestamp);
            end
            realizedVols = obj.spread.getTableVar('SD', obj.timestamp);
            defaultVol = obj.stock.getPrice1dVar(['SD' num2str(namedConst.defaultVolNrDays)], obj.timestamp);
            volTxt = prin('Vol Chosen Option ~, Realized %4W ~, Implied %4W ~, %s default Realized %4W', realizedVols(whichIV), IVs(whichIV), obj.stock.symbol, defaultVol);
            
            set(S.volText, 'string', volTxt);
            plMaxPLot = max(PL)+0.5*(max(PL)-min(PL));
            
            % bars
            if xVar == 1
                xBreakEvens = obj.zeroCrossings(PL, X); 
                maxArr = plMaxPLot * ones(1, numel(xBreakEvens));
                minArr = min(PL) * ones(1, numel(xBreakEvens));
                bars = Pvbar(xBreakEvens, 2*minArr, 2*maxArr);
                set(S.tr(1), 'x', real(bars), 'y', imag(bars), 'Linestyle', ':', 'LineWidth', 0.7);
                theoPosition = theoAct - spreadPrice;
                bars = Pvbar(obj.stock.getPrice1dVar('last', obj.timestamp), theoPosition, 2*plMaxPLot);
                set(S.tr(2), 'x', real(bars), 'y', imag(bars), 'Marker', '+', 'MarkerSize', 5,'Linestyle', ':', 'LineWidth', 1.8);
                midPosition = obj.spread.getMid(obj.timestamp) - spreadPrice;
                bars = Pvbar(obj.stock.getPrice1dVar('last', obj.timestamp), 2*min(PL), midPosition);
                set(S.tr(3), 'x', real(bars), 'y', imag(bars), 'Marker', '+', 'MarkerSize', 5,'Linestyle', ':', 'LineWidth', 1.8);
                midPositionCommissions = obj.spread.getMidInclCommissions(obj.timestamp) - spreadPrice;
                bars = Pvbar(obj.stock.getPrice1dVar('last', obj.timestamp), midPosition, midPositionCommissions);
                set(S.tr(4), 'x', real(bars), 'y', imag(bars), 'Marker', '+', 'MarkerSize', 5,'Linestyle', ':', 'LineWidth', 1.8);
                % hist SD till exp
                SDs = obj.spread.getTableVar('SD', obj.timestamp);
                SigmaAtExp = SDs(1) * sqrt(daysTillExpNearNow / namedConst.daysPerYear);
                sdMove = [1 - SigmaAtExp, 1 + SigmaAtExp] * obj.stock.getPrice1dVar('last', obj.timestamp); 
                bars = Pvbar(sdMove, [2*min(PL), 2*min(PL)], [2*plMaxPLot, 2*plMaxPLot]);
                set(S.tr(6), 'x', real(bars), 'y', imag(bars), 'Linestyle', '--', 'LineWidth', 0.7);
                % IV first option                
                IVAtExp = IVs(whichIV) * sqrt(daysTillExpNearNow / namedConst.daysPerYear);
                ivMove = [1 - IVAtExp, 1 + IVAtExp] * obj.stock.getPrice1dVar('last', obj.timestamp);
                bars = Pvbar(ivMove, [2*min(PL), 2*min(PL)], [2*plMaxPLot, 2*plMaxPLot]);
                set(S.tr(7), 'x', real(bars), 'y', imag(bars), 'Linestyle', '--', 'LineWidth', 0.7);
            end
            
            % set lims only first time
            if xVar ~= obj.currentXVar
                obj.currentXVar = xVar;
                obj.limsSet = false;
            end
            if ~obj.limsSet
                obj.limsSet = true;
                minGreeks = min([min(delta) min(gamma) min(theta) min(vega)]);
                maxGreeks = max([max(delta) max(gamma) max(theta) max(vega)]);
                plt('cursor',-1,'xlim',[min(X) max(X)], 'ylimR', [minGreeks-2*(maxGreeks-minGreeks) maxGreeks]);
                plt('cursor',-1,'ylim', [min(PL) plMaxPLot]);
            end
        end
    end

end

