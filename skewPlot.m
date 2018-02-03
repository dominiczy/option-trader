classdef skewPlot < plotObj
    %UNTITLED3 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        skewType = 'strike';
        lastMontlySetting = 1;
        lastPutCallSetting = 1;
        lastQuantity = 0;
        nrExpDates;
        minStrike;
        maxStrike;
        minDate;
        maxDate;
        minVol;
        maxVol;
        maxYR = 1;
        minYR = 0;
    end
    
    properties (Constant)
        trafoOpt = {'No trafo' 'Rel mov, % ATM'}
        putCallOpt = {'call and put' 'call' 'put'}
        monthlyOpt = {'monthly, weekly, quarterly' 'monthly' 'not monthly' 'none' }
        extraTraceOpt = {'Total volume' 'Call volume' 'Put volume' 'Avg realized vol'}
        txtOpt = 'Select option for info'
    end
    
    methods
        function obj = skewPlot(stock, skewType, varargin)
            fprintf('Constructing skewPlot.\n')
            obj = obj@plotObj(stock, varargin{:});
            
            if ~exist('skewType', 'var') || isempty(skewType)
                obj.skewType = 'strike';
                obj.lbx = 'Strike'; 
            elseif strcmpi(skewType, 'date')
                obj.skewType = 'date';
                obj.lbx = 'Days from now'; 
            elseif (strcmpi(skewType, 'surface')) || (strcmpi(skewType, 'both'))
                obj.skewType = 'surface'; 
            end
                
            obj.lby = {'Implied volatility' 'Extra trace'}; 
            obj.plotPosition = [.275 .105 .660 .760];
            obj.popupBottomLeftPosition = [.260 .710 .100 .200];
            obj.popupTopLeftPosition = [.260 .880 .040 .070];
            obj.popupTopRightPosition = [.460 .750 .024 .200];
            obj.popupBottomRightPosition = [.460 .710 .024 .200];
            if nargin > 0
                obj.setVars();
                obj.createPlot();
            end
        end
        
        function setVars (obj)
            obj.figName = [obj.stock.symbol ': Implied Volatility Skew: ' obj.skewType];
            obj.minStrike = min(obj.stock.getOption2dVar('strike', obj.timestamp));
            obj.maxStrike = max(obj.stock.getOption2dVar('strike', obj.timestamp));
            obj.minVol = min(min(obj.stock.getOption2dVar('putIV', obj.timestamp)),min(obj.stock.getOption2dVar('callIV', obj.timestamp)));
            obj.maxVol = max(max(obj.stock.getOption2dVar('putIV', obj.timestamp)),max(obj.stock.getOption2dVar('callIV', obj.timestamp)));
            switch obj.skewType
                case 'strike'
                    expDates = unique(obj.stock.getOption2dVar('expDate', obj.timestamp));
                    obj.nrExpDates = numel(expDates);
                    datesStr = transpose(cellstr(datestr(expDates,'ddmmmyy')));
                    obj.traceIDs = [strcat(datesStr, ' C') strcat(datesStr, ' P') strcat(datesStr, ' +') 'Stock Price' 'SDOneTwoDefault' 'SDOneTwoImplied'];
                    obj.rightStart = numel(datesStr) * 2 + 1;
                case 'date'
                    obj.traceIDs = {'Avg IV' 'Put Avg IV' 'Call Avg IV' 'Put ATM IV' 'Call ATM IV' 'VIX IV' 'n days moving SD' 'dummyRight'};
                    obj.rightStart = numel(obj.traceIDs);
            end
        end
        
        function createPlot (obj)
            fprintf('Executing %s: createPlot.\n', class(obj))
            switch obj.skewType
                case 'strike' 
                    S.tr = obj.newPlt('TIDcolumn', [obj.nrExpDates (numel(obj.traceIDs)- 2 *obj.nrExpDates)], 'moveCB', @obj.moveCursor);
                    S.trafo = plt('pop', obj.popupTopLeftPosition, obj.trafoOpt,'callbk',@obj.clb,'swap');
                    S.putCall = plt('pop', obj.popupBottomLeftPosition, obj.putCallOpt,'callbk',@obj.clb,'swap');
                    S.monthly = plt('pop', obj.popupTopRightPosition, obj.monthlyOpt,'callbk',@obj.clb,'swap');
                    S.extraTrace = plt('pop', obj.popupBottomRightPosition, obj.extraTraceOpt,'callbk',@obj.clb,'swap');
                    txtPos = obj.textBottomLeftPosition;
                    S.optText = text(txtPos(1), txtPos(2), obj.txtOpt,'units','norm','horiz','center','color',[.2 .6 1]);
                    S.buySell   = plt('edit',  obj.textBottomRightPosition ,[0 -20 20],'callbk',@obj.moveCursor,'label','Buy/sell:');
                case 'date'
                    S.tr = obj.newPlt('xstring','sprintf("Date: %s",datestr(datenum(@XVAL+datenum(today))))');
            end
            
            txtPos = obj.textUnderLegendPosition;
            S.volText = text(txtPos(1), txtPos(2),'Vol text here!!','units','norm','horiz','center','color',[.2 .6 1]);
           
            set(gcf, 'user', S);
            obj.clb();    % initialize plot
        end
        
        function clb(obj) % callback function for all objects
            S = get(gcf, 'user'); % retrieve config
            obj.maxYR = 0;
            switch obj.skewType
                case 'strike'
                    % FIXME trafo needs implementing
                    trafo = plt('pop', S.trafo);
                    expDates = obj.stock.getOption2dVar('expDate', obj.timestamp);
                    putIVs = obj.stock.getOption2dVar('putIV', obj.timestamp);
                    callIVs = obj.stock.getOption2dVar('callIV', obj.timestamp);
                    putVols = obj.stock.getOption2dVar('putVol', obj.timestamp);
                    callVols = obj.stock.getOption2dVar('callVol', obj.timestamp);
                    SDs = obj.stock.getOption2dVar('SD', obj.timestamp);
                    monthlies = obj.stock.getOption2dVar('monthlyExpDate', obj.timestamp);
                    uniqueExpDates = unique (expDates);
                    monthlyIdx = false(1, numel(uniqueExpDates));
                    strikes = obj.stock.getOption2dVar ('strike', obj.timestamp);
                    % reset view if trafo is chosen
                    if trafo == 2
                        obj.limsSet = false;
                        obj.minStrike = 0;
                        obj.maxStrike = 0;
                        obj.minVol = 999;
                        obj.maxVol = 0;
                    end
                    for dateNr = 1:numel(uniqueExpDates)
                        indicesDate = (expDates == uniqueExpDates(dateNr));
                        strike = strikes(indicesDate);
                        monthliesDate = monthlies(indicesDate);
                        monthlyIdx(1, dateNr) = monthliesDate(1);
                        putIV = putIVs(indicesDate);
                        callIV = callIVs(indicesDate);
                        if trafo == 2
                            
                            forwardPrice = obj.stock.getPrice1dVar('last', obj.timestamp) % slightly inaccurate
                            [~, minIdx] = min(abs(strike - forwardPrice));
                            forwardStrike = strike(minIdx)
                            timeTillExp = (datenum(uniqueExpDates(dateNr)) - datenum(obj.stock.getTimestamp(obj.timestamp))) / namedConst.daysPerYear;
                            strike = log(strike / forwardPrice) ./ timeTillExp;

                            OTMIV = putIV(minIdx)
                            putIV = 100*putIV / OTMIV;
                            callIV = 100*callIV / OTMIV;
                            obj.minStrike = min(min(strike), obj.minStrike);
                            obj.maxStrike = max(max(strike), obj.maxStrike);
                            obj.minVol = min(min(putIV), obj.minVol);
                            obj.maxVol = max(max(putIV), obj.maxVol);
                        end
                        set(S.tr(dateNr), 'x', strike, 'y', callIV, 'Marker', '*', 'MarkerSize', 4, 'Linestyle', '-.');
                        set(S.tr(dateNr + numel(uniqueExpDates)), 'x', strike, 'y', putIV, 'Marker', '*', 'MarkerSize', 4, 'Linestyle', '-');
                        extraTrace = plt('pop', S.extraTrace);
                        extraIdx = true(3, numel(uniqueExpDates));
                        if extraTrace < 3
                            if extraTrace == 1 % total volume
                                vol = callVols(indicesDate) + putVols(indicesDate);
                            elseif extraTrace == 2 % call volume
                                vol = callVols(indicesDate);
                            elseif extraTrace == 3 % put volume
                                vol = putVols(indicesDate);
                            end
                            bars = Pvbar(strike, 0, vol);
                            set(S.tr(dateNr + 2*numel(uniqueExpDates)), 'x', real(bars), 'y', imag(bars), 'Linestyle', '-', 'LineWidth', 2);
                            obj.minYR = 0;
                            obj.maxYR = max(max(imag(bars) * 2), obj.maxYR);
                        elseif extraTrace == 4 % avg realized vol
                            avgSD = SDs(indicesDate);
                            set(S.tr(dateNr + 2*numel(uniqueExpDates)), 'x', strike, 'y', avgSD, 'Linestyle', '--', 'LineWidth', 0.5); 
                            obj.minYR = obj.minVol;
                            obj.maxYR = obj.maxVol;
                        else % none
                            extraIdx = false(3, numel(uniqueExpDates));
                            % prevent error
                            obj.maxYR = obj.maxVol;
                        end
                    end  
                    % current price bar
                    barsIdx = true(1,3); % currently only price and SD bars
                    bars = Pvbar(obj.stock.getPrice1dVar('last', obj.timestamp), 0, 999999);
                    set(S.tr(1 + 3*numel(uniqueExpDates)), 'x', real(bars), 'y', imag(bars), 'Linestyle', ':', 'LineWidth', 2);
 
                    % read back popups
                    putCall = plt('pop', S.putCall);
                    monthly = plt('pop', S.monthly);                     
                    % check if was changed since last time
                    if monthly ~= obj.lastMontlySetting || putCall ~= obj.lastPutCallSetting
                        monthlyIdx = [true(1, numel(uniqueExpDates)*3); monthlyIdx, monthlyIdx, monthlyIdx; ~monthlyIdx, ~monthlyIdx, ~monthlyIdx; false(1, numel(uniqueExpDates)*3)];
                        putCallIdx = [true(1, numel(uniqueExpDates)*2); true(1, numel(uniqueExpDates)), false(1, numel(uniqueExpDates)); false(1, numel(uniqueExpDates)), true(1, numel(uniqueExpDates))];
                        putCallIdx = [putCallIdx, extraIdx];
                        obj.lastMontlySetting = monthly;
                        obj.lastPutCallSetting = putCall;
                        newIdx = monthlyIdx(monthly,:) & putCallIdx(putCall,:);
                        plt('show',[newIdx barsIdx]);
                    end
                    if ~obj.limsSet
                        obj.limsSet = true;
                        plt('cursor',-1,'xLim', [obj.minStrike obj.maxStrike], 'yLimR', [obj.minYR obj.maxYR]);
                        plt('cursor',-1,'yLim', [obj.minVol obj.maxVol]);
                    end
                case 'date'
                    expDates = obj.stock.getOption2dVar('expDate', obj.timestamp);
                    [uniqueExpDates, idxExpDates, idxUnique] = unique (expDates);
                    X = datenum(uniqueExpDates) - today;
                    IVs = obj.stock.getOption2dVar('avgIV', obj.timestamp);
                    vixIVs = obj.stock.getOption2dVar('vixIV', obj.timestamp);
                    callIVs = obj.stock.getOption2dVar('avgCallIV', obj.timestamp);
                    putIVs = obj.stock.getOption2dVar('avgPutIV', obj.timestamp);
                    atmCallIVs = obj.stock.getOption2dVar('atmCallIV', obj.timestamp);
                    atmPutIVs = obj.stock.getOption2dVar('atmPutIV', obj.timestamp);
                    avgIV = IVs(idxExpDates);
                    set(S.tr(1), 'x', X, 'y', avgIV, 'Marker', '*', 'MarkerSize', 4);
                    avgCallIV = callIVs(idxExpDates);
                    set(S.tr(3), 'x', X, 'y', avgCallIV, 'Marker', '*', 'MarkerSize', 4);
                    avgPutIV = putIVs(idxExpDates);
                    set(S.tr(2), 'x', X, 'y', avgPutIV, 'Marker', '*', 'MarkerSize', 4);
                    atmCallIV = atmCallIVs(idxExpDates);
                    set(S.tr(5), 'x', X, 'y', atmCallIV, 'Marker', '*', 'MarkerSize', 4);
                    atmPutIV = atmPutIVs(idxExpDates);
                    set(S.tr(4), 'x', X, 'y', atmPutIV, 'Marker', '*', 'MarkerSize', 4);
                    vixIV = vixIVs(idxExpDates);
                    set(S.tr(6), 'x', X, 'y', vixIV, 'Marker', '*', 'MarkerSize', 4);
                    SDs = obj.stock.getOption2dVar('SD', obj.timestamp);
                    SD = SDs(idxExpDates);
                    set(S.tr(7), 'x', X, 'y', SD, 'Marker', '*', 'MarkerSize', 4, 'Linestyle', '--');
                    maxIV = max(max(avgCallIV),max(avgPutIV));
                    plt('show',[    1 2 3 4 5 6 7]);
                    if ~obj.limsSet
                        obj.limsSet = true;
                        plt('cursor',-1,'yLim', [0 maxIV]);
                        plt('cursor',-1,'xLim', [0 max(X)]);
                    end
            end
            
        end       
        
        % show option delta, price, theo on cursor move
        function moveCursor (obj)
            if strcmpi(obj.skewType, 'strike')
                [xy, index] = plt('cursor',-1,'get');
                [traceNr, lineHandle] = plt('cursor', 0,'getActive');
                % if not initialization
                if ~(real(xy) == 0 && imag(xy) == 0)
                    % get date from traceNr
                    expDates = obj.stock.getOption2dVar('expDate', obj.timestamp);
                    strikes = obj.stock.getOption2dVar('strike', obj.timestamp);
                    callDelta = obj.stock.getOption2dVar('callDelta', obj.timestamp);
                    callImpliedDelta = obj.stock.getOption2dVar('ICallDelta', obj.timestamp);
                    callTheo = obj.stock.getOption2dVar('callTheo', obj.timestamp);
                    callMid = obj.stock.getOption2dVar('callMid', obj.timestamp);
                    callVlm = obj.stock.getOption2dVar('callVol', obj.timestamp);
                    callQuantity = obj.stock.getOption2dVar('callQuantity', obj.timestamp);
                    putDelta = obj.stock.getOption2dVar('putDelta', obj.timestamp);
                    putImpliedDelta = obj.stock.getOption2dVar('IPutDelta', obj.timestamp);
                    putTheo = obj.stock.getOption2dVar('putTheo', obj.timestamp);
                    putMid = obj.stock.getOption2dVar('putMid', obj.timestamp);
                    putVlm = obj.stock.getOption2dVar('putVol', obj.timestamp);
                    putQuantity = obj.stock.getOption2dVar('putQuantity', obj.timestamp);
                    [uniqueExpDates, idxExpDates, idxUnique] = unique (expDates);
                    nrDates = numel(uniqueExpDates);
                    S = get(gcf, 'user'); % retrieve config
                    % if not extraTrace selected
                    if traceNr <= 2 * nrDates
                        dateNr = mod( traceNr,nrDates);
                        if dateNr == 0
                            dateNr = nrDates;
                        end
                        dateIndices = find((expDates == uniqueExpDates(dateNr)));
                        dateIndex = dateIndices(index);
                        expDate = datestr(uniqueExpDates(dateNr));
                        strike = strikes(dateIndex);
                        if traceNr <= nrDates % call selected
                            delta = callDelta(dateIndex);
                            impliedDelta = callImpliedDelta(dateIndex);
                            theo = callTheo(dateIndex);
                            mid = callMid(dateIndex);
                            vlm = callVlm(dateIndex);
                            putCall = 'Call';
                            newQuantity = callQuantity(dateIndex);
                        else % put selected
                            delta = putDelta(dateIndex);
                            impliedDelta = putImpliedDelta(dateIndex);
                            theo = putTheo(dateIndex);
                            mid = putMid(dateIndex);
                            vlm = putVlm(dateIndex);
                            putCall = 'Put';
                            newQuantity = putQuantity(dateIndex);
                        end
                         % draw bars SD
                        strikesDate = strikes(dateIndices);
                        [uniPutDeltas, uniIdx, ~] = unique(putDelta(dateIndices));
                        oneSDPut = interp1(uniPutDeltas, strikesDate(uniIdx), -namedConst.sdOneDelta);
                        twoSDPut = interp1(uniPutDeltas, strikesDate(uniIdx), -namedConst.sdTwoDelta);
                        [uniCallDeltas, uniIdx, ~] = unique(callDelta(dateIndices));
                        oneSDCall = interp1(uniCallDeltas, strikesDate(uniIdx), namedConst.sdOneDelta);
                        twoSDCall = interp1(uniCallDeltas, strikesDate(uniIdx), namedConst.sdTwoDelta);
                        bars = Pvbar([twoSDPut oneSDPut oneSDCall twoSDCall], zeros(4,1), 999999*ones(4,1));
                        set(S.tr(2 + 3*numel(uniqueExpDates)), 'x', real(bars), 'y', imag(bars), 'Linestyle', ':', 'LineWidth', 1);
                        % implied SD
                        [uniImpliedPutDeltas, uniIdx, ~] = unique(putImpliedDelta(dateIndices));
                        strikesDatePut = strikesDate(uniIdx);
                        nonNanIdx = ~isnan(uniImpliedPutDeltas);
                        oneSDImpliedPut = interp1(uniImpliedPutDeltas(nonNanIdx), strikesDatePut(nonNanIdx), -namedConst.sdOneDelta);
                        twoSDImpliedPut = interp1(uniImpliedPutDeltas(nonNanIdx), strikesDatePut(nonNanIdx), -namedConst.sdTwoDelta);
                        [uniImpliedCallDeltas, uniIdx, ~] = unique(callImpliedDelta(dateIndices));
                        strikesDateCall = strikesDate(uniIdx);
                        nonNanIdx = ~isnan(uniImpliedCallDeltas);
                        oneSDImpliedCall = interp1(uniImpliedCallDeltas(nonNanIdx), strikesDateCall(nonNanIdx), namedConst.sdOneDelta);
                        twoSDImpliedCall = interp1(uniImpliedCallDeltas(nonNanIdx), strikesDateCall(nonNanIdx), namedConst.sdTwoDelta);
                         bars = Pvbar([twoSDImpliedPut oneSDImpliedPut oneSDImpliedCall twoSDImpliedCall], zeros(4,1), 999999*ones(4,1));
                        set(S.tr(3 + 3*numel(uniqueExpDates)), 'x', real(bars), 'y', imag(bars), 'Linestyle', ':', 'LineWidth', 1);

                        % output to command window to allow copying
                        selectedOpt = sprintf("%s, %s, %3.1f: Delta %3.2f, Impl Delta %3.2f, Theo %3.2f, Mid %3.2f, Vlm %d", putCall, expDate, strike, delta, impliedDelta, theo, mid, vlm)
                        set(S.optText,'string', selectedOpt);
                        
                        % check buy sell
                        quantity = plt('edit',S.buySell);
                        if quantity ~= obj.lastQuantity && isempty(obj.timestamp)
                            obj.lastQuantity = quantity; 
                            if traceNr <= nrDates % call selected
                                obj.stock.setOption2dVarFor ('callQuantity', quantity, expDate, strike, [], obj.timestamp);
                            else
                                obj.stock.setOption2dVarFor ('putQuantity', quantity, expDate, strike, [], obj.timestamp);
                            end
                            if quantity == 0 
                                obj.stock.setOption2dVarFor ('spreadComment', '', expDate, strike, [], obj.timestamp);
                            else
                                obj.stock.setOption2dVarFor ('spreadComment', 'From skew plot', expDate, strike, [], obj.timestamp);
                            end
                            quantityTable = obj.stock.getSpreads (obj.timestamp)
                        else % show current quantity
                            set(S.buySell,'string', newQuantity);
                        end
                    else
                        set(S.optText,'string', obj.txtOpt); 
                    end
                end
            end
        end
    end
end

