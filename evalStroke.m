function h = evalStroke(strokes,i)
    disp(sprintf('stroke %i',i));
    [corners segtypes] = segmentStroke(strokes(i));
    h = showSegmentation(strokes(i),corners,segtypes);
end

