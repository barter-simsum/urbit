import { Col } from '@tlon/indigo-react';
import {
    IndexedNotification,
    JoinRequests,
    Notifications,
    seen,
    Timebox,
    unixToDa
} from '@urbit/api';
import { BigInteger } from 'big-integer';
import _ from 'lodash';
import f from 'lodash/fp';
import moment from 'moment';
import React, { useEffect } from 'react';
import { getNotificationKey } from '~/logic/lib/hark';
import { daToUnix } from '~/logic/lib/util';
import useHarkState from '~/logic/state/hark';
import { Invites } from './invites';
import { Notification } from './notification';
import airlock from '~/logic/api';

type DatedTimebox = [BigInteger, Timebox];

function filterNotification(groups: string[]) {
  if (groups.length === 0) {
    return () => true;
  }
  return (n: IndexedNotification) => {
    if ('graph' in n.index) {
      const { group } = n.index.graph;
      return groups.findIndex(g => group === g) !== -1;
    } else if ('group' in n.index) {
      const { group } = n.index.group;
      return groups.findIndex(g => group === g) !== -1;
    }
    return true;
  };
}

export default function Inbox(props: {
  archive: Notifications;
  showArchive?: boolean;
  filter: string[];
  pendingJoin: JoinRequests;
}) {
  useEffect(() => {
    let hasSeen = false;
    setTimeout(() => {
      hasSeen = true;
    }, 3000);
    return () => {
      if (hasSeen) {
        airlock.poke(seen());
      }
    };
  }, []);

  const ready = useHarkState(
    s => Object.keys(s.unreads.graph).length > 0
  );

  const getMore = useHarkState(s => s.getMore);

  const notificationState = useHarkState(state => state.notifications);
  const unreadNotes = useHarkState(s => s.unreadNotes);
  const archivedNotifications = useHarkState(state => state.archivedNotifications);

  const notifications =
    Array.from(props.showArchive ? archivedNotifications : notificationState) || [];

  const notificationsByDay = f.flow(
    f.map<DatedTimebox, DatedTimebox>(([date, nots]) => [
      date,
      nots.filter(filterNotification(props.filter))
    ]),
    f.groupBy<DatedTimebox>(([d]) => {
      const date = moment(daToUnix(d));
      if (moment().subtract(6, 'hours').isBefore(date)) {
        return 'latest';
      } else {
        return date.format('YYYYMMDD');
      }
    })
  )(notifications);

  const notificationsByDayMap = new Map<string, DatedTimebox[]>(
    Object.keys(notificationsByDay).map((timebox) => {
      return [timebox, notificationsByDay[timebox]];
    })
  );

  const date = unixToDa(Date.now());

  return (
    <Col p={1} position="relative" height="100%" overflowY="auto" overflowX="hidden">
      <Invites pendingJoin={props.pendingJoin} />
    </Col>
  );
}

function sortTimeboxes([a]: DatedTimebox, [b]: DatedTimebox) {
  return b.subtract(a);
}

function sortIndexedNotification(
  { notification: a }: IndexedNotification,
  { notification: b }: IndexedNotification
) {
  return b.time - a.time;
}

function DaySection({
  timeboxes,
  unread = false
}) {
  const lent = timeboxes.map(([,nots]) => nots.length).reduce(f.add, 0);
  if (lent === 0 || timeboxes.length === 0) {
    return null;
  }

  return (
    <>
      {_.map(timeboxes.sort(sortTimeboxes), ([date, nots], i: number) =>
        _.map(nots.sort(sortIndexedNotification), (not, j: number) => (
          <Notification
            key={getNotificationKey(date, not)}
            notification={not}
            unread={unread}
            time={!unread ? date : undefined}
          />
        ))
      )}
    </>
  );
}
