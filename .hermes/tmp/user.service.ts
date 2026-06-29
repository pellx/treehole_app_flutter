import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, QueryFailedError, TypeORMError } from 'typeorm';
import { DeviceEntity, FollowEntity, FollowAuthorEntity, UserSettingEntity } from '../migration/entities';
import { UserEntity } from './entities';

@Injectable()
export class UserService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(DeviceEntity)
    private readonly deviceRepo: Repository<DeviceEntity>,
    @InjectRepository(FollowEntity)
    private readonly followRepo: Repository<FollowEntity>,
    @InjectRepository(FollowAuthorEntity)
    private readonly followAuthorRepo: Repository<FollowAuthorEntity>,
    @InjectRepository(UserSettingEntity)
    private readonly settingRepo: Repository<UserSettingEntity>,
  ) {}

  async getUserData(userToken: string) {
    const user = await this.userRepo.findOne({ where: { internal_token: userToken } });
    if (!user) {
      return { follows: [], followAuthors: [], settings: [] };
    }

    const [follows, followAuthors, settings] = await Promise.all([
      this.followRepo.find({ where: { user_token: userToken } }),
      this.followAuthorRepo.find({ where: { user_token: userToken } }),
      this.settingRepo.find({ where: { user_token: userToken } }),
    ]);

    return { follows, followAuthors, settings };
  }

  async addFollow(userToken: string, postId: number, title?: string, author?: string, lastUpdated?: string) {
    if (!userToken) throw new BadRequestException('userToken is required');
    if (!postId || postId < 1 || !Number.isInteger(postId)) throw new BadRequestException('Invalid postId');

    await this.ensureUser(userToken);

    try {
      const result = await this.followRepo
        .createQueryBuilder()
        .insert()
        .values({
          user_token: userToken,
          post_id: postId,
          title: title ?? undefined,
          author: author ?? undefined,
          last_updated: lastUpdated ?? undefined,
        })
        .orIgnore()
        .updateEntity(false)
        .execute();
      if (!(result.raw?.affectedRows > 0)) {
        return { success: false, error: 'Already followed' };
      }
      return { success: true };
    } catch (e) {
      if (e instanceof QueryFailedError && (e as any).driverError?.code === 'ER_DUP_ENTRY') {
        return { success: false, error: 'Already followed' };
      }
      if (e instanceof TypeORMError && e.message.includes('entity id is not set')) {
        return { success: false, error: 'Already followed' };
      }
      throw e;
    }
  }

  async removeFollow(userToken: string, postId: number) {
    if (!userToken) throw new BadRequestException('userToken is required');
    if (!postId || postId < 1) throw new BadRequestException('Invalid postId');

    const result = await this.followRepo.delete({ user_token: userToken, post_id: postId });
    if (result.affected === 0) {
      return { success: false, error: 'Follow not found' };
    }
    return { success: true };
  }

  async addFollowAuthor(userToken: string, author: string) {
    if (!userToken) throw new BadRequestException('userToken is required');
    if (!author || !author.trim()) throw new BadRequestException('author is required');

    await this.ensureUser(userToken);

    try {
      const result = await this.followAuthorRepo
        .createQueryBuilder()
        .insert()
        .values({ user_token: userToken, author })
        .orIgnore()
        .updateEntity(false)
        .execute();
      if (!(result.raw?.affectedRows > 0)) {
        return { success: false, error: 'Already followed' };
      }
      return { success: true };
    } catch (e) {
      if (e instanceof QueryFailedError && (e as any).driverError?.code === 'ER_DUP_ENTRY') {
        return { success: false, error: 'Already followed' };
      }
      if (e instanceof TypeORMError && e.message.includes('entity id is not set')) {
        return { success: false, error: 'Already followed' };
      }
      throw e;
    }
  }

  async removeFollowAuthor(userToken: string, author: string) {
    if (!userToken) throw new BadRequestException('userToken is required');
    if (!author) throw new BadRequestException('author is required');

    const result = await this.followAuthorRepo.delete({ user_token: userToken, author });
    if (result.affected === 0) {
      return { success: false, error: 'Author follow not found' };
    }
    return { success: true };
  }

  async updateSettings(userToken: string, settings: Record<string, string>) {
    if (!userToken) throw new BadRequestException('userToken is required');
    if (!settings || typeof settings !== 'object') throw new BadRequestException('settings object is required');

    await this.ensureUser(userToken);

    const keys = Object.keys(settings);
    if (keys.length === 0) return { success: true };

    const existingSettings = await this.settingRepo.find({
      where: { user_token: userToken },
    });
    const settingMap = new Map(existingSettings.map((s) => [s.setting_key, s]));

    const entitiesToSave: UserSettingEntity[] = [];

    for (const [key, value] of Object.entries(settings)) {
      const existing = settingMap.get(key);
      if (existing) {
        existing.setting_value = value;
        entitiesToSave.push(existing);
      } else {
        entitiesToSave.push(
          this.settingRepo.create({
            user_token: userToken,
            setting_key: key,
            setting_value: value,
          }),
        );
      }
    }

    await this.settingRepo.save(entitiesToSave);
    return { success: true };
  }

  async syncData(
    userToken: string,
    data: {
      follows?: Record<string, unknown>[];
      followAuthors?: Record<string, unknown>[];
      settings?: Record<string, string>;
    },
  ) {
    if (!userToken) throw new BadRequestException('userToken is required');

    await this.ensureUser(userToken);

    return this.userRepo.manager.transaction(async (manager) => {
      const followRepo = manager.getRepository(FollowEntity);
      const followAuthorRepo = manager.getRepository(FollowAuthorEntity);
      const settingRepo = manager.getRepository(UserSettingEntity);

      if (data.follows) {
        await followRepo.delete({ user_token: userToken });
        if (data.follows.length > 0) {
          const entities = data.follows
            .filter((f) => f.postId != null && typeof f.postId === 'number' && f.postId >= 1)
            .map((f) =>
              followRepo.create({
                user_token: userToken,
                post_id: f.postId as number,
                title: typeof f.title === 'string' ? f.title : undefined,
                author: typeof f.author === 'string' ? f.author : undefined,
                last_updated: typeof f.lastUpdated === 'string' ? f.lastUpdated : undefined,
              }),
            );
          if (entities.length > 0) {
            await followRepo.save(entities);
          }
        }
      }

      if (data.followAuthors) {
        await followAuthorRepo.delete({ user_token: userToken });
        if (data.followAuthors.length > 0) {
          const entities = data.followAuthors
            .filter((a) => a.author != null && typeof a.author === 'string' && a.author.trim().length > 0)
            .map((a) =>
              followAuthorRepo.create({
                user_token: userToken,
                author: a.author as string,
              }),
            );
          if (entities.length > 0) {
            await followAuthorRepo.save(entities);
          }
        }
      }

      if (data.settings) {
        await settingRepo.delete({ user_token: userToken });
        if (Object.keys(data.settings).length > 0) {
          const entities = Object.entries(data.settings)
            .filter(([key]) => key.trim().length > 0)
            .map(([key, value]) =>
              settingRepo.create({
                user_token: userToken,
                setting_key: key,
                setting_value: value,
              }),
            );
          if (entities.length > 0) {
            await settingRepo.save(entities);
          }
        }
      }

      return { success: true };
    });
  }

  private async ensureUser(userToken: string) {
    await this.userRepo
      .createQueryBuilder()
      .insert()
      .into(UserEntity)
      .values({ internal_token: userToken })
      .orIgnore()
      .updateEntity(false)
      .execute();
  }
}
